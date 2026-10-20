variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "notes-api"
}

variable "github_repo" {
  type        = string
  description = "Репозиторій у форматі OWNER/REPO - йому дозволено деплоїти через OIDC"
}

variable "alert_email" {
  type        = string
  description = "Email для сповіщень бюджету"
}

variable "budget_usd" {
  type    = number
  default = 10
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "image_tag" {
  type        = string
  default     = "initial"
  description = "Початковий тег образу. Далі тег (хеш коміту) оновлює CI/CD, а не Terraform."
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "container_port" {
  type    = number
  default = 8000
}
