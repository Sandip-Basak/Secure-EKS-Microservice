output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets for EKS Worker Nodes"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets for external ALBs"
  value       = module.vpc.public_subnets
}

output "database_subnets" {
  description = "List of IDs of isolated database subnets"
  value       = module.vpc.database_subnets
}

output "cluster_endpoint" {
  description = "Internal Private Endpoint for EKS Control Plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for IRSA integration"
  value       = module.eks.oidc_provider_arn
}

output "rds_endpoint" {
  description = "The connection endpoint for the managed MySQL instance"
  value       = aws_db_instance.mysql.address
}

output "redis_primary_endpoint" {
  description = "The connection endpoint for the Redis configuration loop"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "secrets_manager_db_arn" {
  description = "The ARN of the AWS Secrets Manager entry tracking credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

# ==========================================
# Output the ARN for the CI/CD GitOps Glue
# ==========================================
output "eso_iam_role_arn" {
  description = "The ARN of the IAM Role for the External Secrets Operator ServiceAccount"
  value       = aws_iam_role.eso_role.arn
}