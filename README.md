# Notes API

REST API для нотаток (Python / FastAPI / PostgreSQL), розгорнутий в AWS через Terraform.

**Публічна адреса:** `http://<ALB_DNS_NAME>` _(підставити з `terraform output app_url`)_
**Swagger UI:** `http://<notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com>/docs`

## Ендпоінти
| Метод | Шлях | Опис |
|---|---|---|
| GET | `/` | версія (хеш коміту) і hostname контейнера |
| GET | `/health` | health check балансувальника |
| GET | `/health/db` | перевірка з'єднання з БД |
| GET/POST | `/api/notes` | список / створення |
| GET/PUT/DELETE | `/api/notes/{id}` | читання / оновлення / видалення |

## Архітектура
```
Інтернет -> ALB (public subnets, :80) -> ECS Fargate (2 задачі, :8000) -> RDS PostgreSQL (private subnets, :5432)
GitHub Actions --OIDC--> IAM role --> ECR (образ, тег = SHA коміту) --> ECS (оновлення сервісу)
```

## Структура проєкту
```
app/                  код застосунку
Dockerfile            образ (python:3.12.7-slim-bookworm, не root)
compose.yaml          локальний запуск: застосунок + PostgreSQL (volume)
terraform/            вся інфраструктура AWS
  network.tf          VPC, публічні та приватні підмережі
  security.tf         security groups: ALB -> app -> DB
  ecr.tf rds.tf alb.tf ecs.tf
  github_oidc.tf      OIDC provider і роль для CI/CD
  budget.tf           бюджет зі сповіщенням на email
.github/workflows/    CI/CD: push у main -> build -> ECR -> ECS
docs/                 GUIDE.md (інструкція), ANSWERS.md (відповіді до захисту)
```

## Локальний запуск
```bash
docker compose up --build        # http://localhost:8000/docs
docker compose down              # дані зберігаються у volume
```

## Розгортання
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # заповнити
terraform init && terraform apply
terraform destroy                                # прибрати все
```
Детально: [docs/GUIDE.md](docs/GUIDE.md).

## Виконані завдання
1 Контейнер · 2 Terraform + AWS · 3 Мережева ізоляція · 4 Load balancer · 5 CD через OIDC · 8 Swagger UI
