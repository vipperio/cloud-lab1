# Пароль генерує Terraform - у коді та в git його немає.
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnets"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project}-db"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_encrypted = true

  db_name  = "notes"
  username = "notes_admin"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false # у лабі економимо; у проді було б true

  backup_retention_period = 1 # автобекапи + point-in-time recovery
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}

# Рядок підключення живе в Secrets Manager, ECS підставляє його у контейнер як змінну DATABASE_URL.
# RDS Postgres 16 вимагає SSL -> sslmode=require
resource "aws_secretsmanager_secret" "db_url" {
  name                    = "${var.project}/database-url"
  recovery_window_in_days = 0 # видаляється одразу при destroy
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id = aws_secretsmanager_secret.db_url.id
  secret_string = format(
    "postgresql+psycopg://%s:%s@%s:5432/%s?sslmode=require",
    aws_db_instance.main.username,
    random_password.db.result,
    aws_db_instance.main.address,
    aws_db_instance.main.db_name,
  )
}
