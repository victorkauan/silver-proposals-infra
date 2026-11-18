resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "database" {
  name        = "${var.name}-db"
  description = "PostgreSQL, reachable only from the application tasks"
  vpc_id      = var.vpc_id
}

resource "aws_db_parameter_group" "this" {
  name   = var.name
  family = "postgres${var.engine_major_version}"

  # Static parameter: AWS records it as pending-reboot, so declaring the same avoids a perpetual diff.
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_157:Multi-AZ doubles the cost; single-AZ with automated backups is accepted for this project.
  #checkov:skip=CKV_AWS_118:Enhanced monitoring adds cost; CloudWatch metrics and PostgreSQL logs are enough here.
  #checkov:skip=CKV_AWS_353:Performance Insights is not needed at this scale.
  #checkov:skip=CKV2_AWS_30:Query logging is set through log_min_duration_statement and exported to CloudWatch.
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_major_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "postgres"
  username = "silver_admin"
  # RDS creates and keeps the master password in Secrets Manager; it never appears in Terraform.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = false

  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql"]

  backup_retention_period    = var.backup_retention_days
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${var.name}-final"
  apply_immediately          = false
}
