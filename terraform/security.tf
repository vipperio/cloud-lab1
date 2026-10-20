# Інтернет -> ALB (80)
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Public entrypoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "To anywhere (targets)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB -> контейнери (8000). Лише від security group балансувальника.
resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "Containers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB only"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    description = "ECR, Secrets Manager, CloudWatch, RDS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Контейнери -> база (5432). Лише від security group застосунку, не від IP.
resource "aws_security_group" "db" {
  name        = "${var.project}-db-sg"
  description = "Database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from app SG only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  # egress не потрібен: базі нікуди ініціювати з'єднання
}
