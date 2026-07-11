variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Target AWS Deployment Region"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Deployment environment state identifier"
}

variable "cluster_name" {
  type        = string
  default     = "enterprise-eks-mesh"
  description = "Unique identifier for the EKS Cluster"
}