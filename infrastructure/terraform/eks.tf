# ==========================================
# 1. KMS Customer Managed Key for etcd Encryption
# ==========================================
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS Key for EKS Cluster etcd envelope encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Hard compliance audit requirement
}

# ==========================================
# 2. Hardened EKS Control Plane Provisioning
# ==========================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.33" # Utilizing a stable enterprise Kubernetes release

  # Absolute Network Isolation Mandate
  cluster_endpoint_public_access  = false # Blocks all internet-facing kubectl traffic
  cluster_endpoint_private_access = true  # resticts API server visibility strictly within the VPC

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # Workers and control plane ENIs live strictly in private tiers

  # Cryptographic Security Guardrail
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks_secrets.arn
  }

  # Forensic Auditing & Compliance Logging
  # Ensures all API operations, authentications, and controller actions hit CloudWatch permanently
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Identity Security: Enable Identity Provider for IAM Roles for Service Accounts (IRSA)
  enable_irsa = true

  # ==========================================
  # 3. Hardened EKS Managed Node Group Definition
  # ==========================================
  eks_managed_node_groups = {
    core_apps = {
      name         = "node-pool-core-apps"
      min_size     = 2
      max_size     = 5
      desired_size = 3

      instance_types = ["t3.medium"] # Balanced compute/memory for polyglot layers
      capacity_type  = "ON_DEMAND"   # On-demand for core transactional integrity (Django/Node)

      # Ensure worker nodes are launched exclusively in the isolated private subnets
      subnet_ids = module.vpc.private_subnets

      # Security Context for the underlying Node OS
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true # Encrypt node storage at rest
            kms_key_id            = aws_kms_key.eks_secrets.arn
            delete_on_termination = true
          }
        }
      }

      # Restrict Node OS privileges
      iam_role_additional_policies = {
        ssm_management = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # Allows session-manager shell drops, zero SSH ports open
      }

      labels = {
        Role = "application-runtime"
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled"                 = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}"     = "owned"
      }
    }
  }
}