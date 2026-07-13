# ==========================================
# 1. Least-Privilege IAM Policy for Secrets Manager
# ==========================================
resource "aws_iam_policy" "eso_secrets_policy" {
  name        = "${var.environment}-eso-secrets-policy"
  description = "Allows EKS External Secrets Operator to retrieve specific database credentials"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Bounded strictly to the DB credentials secret generated in data_layers.tf
        Resource = [aws_secretsmanager_secret.db_credentials.arn]
      }
    ]
  })
}

# ==========================================
# 2. OIDC Trust Relationship (The Handshake)
# ==========================================
data "aws_iam_policy_document" "eso_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      # Strips "https://" from the OIDC provider URL for compliance with IAM constraints
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      # Limits role assumption strictly to the specific ServiceAccount in your application namespace
      values   = ["system:serviceaccount:default:${var.environment}-multi-tenant-app-eso-sa"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

# ==========================================
# 3. The Target IAM Role & Attachment
# ==========================================
resource "aws_iam_role" "eso_role" {
  name               = "${var.environment}-eks-eso-role"
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "eso_attach" {
  role       = aws_iam_role.eso_role.name
  policy_arn = aws_iam_policy.eso_secrets_policy.arn
}