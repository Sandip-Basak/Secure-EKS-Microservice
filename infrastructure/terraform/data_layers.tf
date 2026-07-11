# ==========================================
# 1. Automated Cryptographic Secrets Generation
# ==========================================
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.environment}-mysql-rds-credentials"
  recovery_window_in_days = 0 # Forces instant deletion if torn down during migration testing
  kms_key_id              = aws_kms_key.eks_secrets.arn
}

resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "mysql"
    host     = aws_db_instance.mysql.address
    port     = "3306"
    username = "enterprise_admin"
    password = random_password.db_password.result
    database = "catalog_production"
  })
}

# ==========================================
# 2. Strict Security Groups (The Firewalls)
# ==========================================

# MySQL Security Group
resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-rds-security-group"
  description = "Enforce isolation for managed MySQL tier"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow MySQL traffic strictly from authenticated EKS worker nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id] # Zero CIDR reliance
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Redis Security Group
resource "aws_security_group" "redis_sg" {
  name        = "${var.environment}-redis-security-group"
  description = "Enforce isolation for managed Redis cache cluster"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow Redis cache traffic strictly from authenticated EKS worker nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 3. Subnet Group Associations
# ==========================================
resource "aws_db_subnet_group" "mysql" {
  name       = "${var.environment}-mysql-subnet-group"
  subnet_ids = module.vpc.database_subnets
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.environment}-redis-subnet-group"
  subnet_ids = module.vpc.database_subnets
}

# ==========================================
# 4. AWS RDS MySQL Instance Configuration
# ==========================================
resource "aws_db_instance" "mysql" {
  identifier        = "${var.environment}-multi-tenant-mysql"
  engine            = "mysql"
  engine_version    = "8.0.35"
  instance_class    = "db.t3.medium"
  allocated_storage = 20
  max_allocated_storage = 100 # Auto-scaling storage enabled to prevent disk exhaustion crashes

  db_name  = "catalog_production"
  username = "enterprise_admin"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  # Structural Architecture Policies
  multi_az               = true # Synchronous hot-standby replication across AZs
  publicly_accessible    = false
  skip_final_snapshot    = true

  # Encryption Mandates
  storage_encrypted = true
  kms_key_id        = aws_kms_key.eks_secrets.arn

  backup_retention_period = 7
  deletion_protection     = false # Toggle to true for actual production environments
}

# ==========================================
# 5. AWS ElastiCache Redis Replication Group
# ==========================================
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = "${var.environment}-cache-mesh"
  description                   = "High-Availability Redis Cache and Celery Broker"
  node_type                     = "cache.t3.medium"
  num_cache_clusters            = 2 # One primary writer, one read-replica with auto failover
  port                          = 6379
  parameter_group_name          = "default.redis7"
  
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis_sg.id]
  automatic_failover_enabled = true

  # Security Mandates
  at_rest_encryption_enabled    = true
  transit_encryption_enabled   = true # Forces encryption over the wire for our Celery/Flask payloads
  kms_key_id                   = aws_kms_key.eks_secrets.arn
}