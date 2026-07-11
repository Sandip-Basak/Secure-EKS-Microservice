data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.environment}-secure-vpc"
  cidr = "10.0.0.0/16"

  # Spread across 3 AZs for high availability
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Subnet allocations
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets  = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"] # /20 for EKS Worker IP cushion
  database_subnets = ["10.0.5.0/24", "10.0.6.0/24", "10.0.7.0/24"]

  # Security Mandates
  enable_nat_gateway     = true
  single_nat_gateway     = false # PRODUCTION REQUIREMENT: One NAT Gateway per AZ. 
  # If single_nat_gateway=true, a single AZ outage takes down internet access for ALL workers, breaking external API drops.
  
  one_nat_gateway_per_az = true
  
  # Isolate Database Routing completely
  create_database_subnet_route_table    = true
  create_database_internet_gateway_route = false # Explicitly block routing to the Internet Gateway
  create_database_nat_gateway_route      = false # Explicitly block internal routing out through NAT Gateways # Denies direct internet access to DBs

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Crucial EKS Subnet Tagging Requirements
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1" # Instructs AWS ALB controller to spawn public ALBs here
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1" # Instructs ALB controller to use these for internal discovery
  }

  database_subnet_tags = {
    "Tier" = "Database-Isolated"
  }
}