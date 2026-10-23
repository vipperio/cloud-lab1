# Notes API

**Адреса застосунку:** http://notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com
**Swagger (документація API):** http://notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com/docs

## Що робить застосунок

Можна створювати, переглядати, змінювати та видаляти нотатки. Усі дані лежать у PostgreSQL.
Сам застосунок нічого не зберігає у себе, тому його можна запускати у кількох копіях.

| Метод            | Шлях              | Що робить                                     |
|------------------|-------------------|-----------------------------------------------|
| GET              | `/`               | показує версію (хеш коміту) і ім'я контейнера |
| GET              | `/health`         | перевірка для балансувальника                 |
| GET              | `/health/db`      | перевіряє зв'язок із базою                    |
| GET, POST        | `/api/notes`      | список нотаток / створення                    |
| GET, PUT, DELETE | `/api/notes/{id}` | читання / зміна / видалення                   |

## Як це працює в хмарі

```
Інтернет -> балансувальник ALB -> 2 контейнери в ECS Fargate -> база RDS PostgreSQL
```

- **ALB** єдиний, хто доступний з інтернету. Він перевіряє `/health` і розподіляє запити між контейнерами.
- **ECS Fargate** запускає два контейнери з мого образу. Порт 8000 відкритий тільки для балансувальника.
- **RDS** стоїть у приватних підмережах без публічної адреси. Підключитися до неї можуть лише контейнери застосунку (правило в security group посилається на групу застосунку, а не на IP).
- **Пароль від бази** генерує Terraform і кладе в AWS Secrets Manager. У коді та в git його немає.
- **Образи** лежать у ECR, тег образу це хеш коміту.

## Автоматичний деплой

При кожному `git push` у гілку `main` запускається GitHub Actions:

1. входить в AWS через OIDC (без збережених ключів);
2. збирає Docker-образ і кладе його в ECR з тегом = хеш коміту;
3. оновлює сервіс в ECS на новий образ.

Роль для деплою може використати тільки цей репозиторій і тільки гілка `main`.

## Структура проєкту

```
app/                   код застосунку (main.py)
Dockerfile             образ: python:3.12.7-slim-bookworm, працює не від root
compose.yaml           локальний запуск: застосунок + PostgreSQL з volume
terraform/             вся інфраструктура AWS
  network.tf           VPC, публічні та приватні підмережі
  security.tf          security groups: ALB -> застосунок -> база
  ecr.tf               реєстр образів
  rds.tf               база даних і секрет із рядком підключення
  alb.tf               балансувальник і health check
  ecs.tf               кластер, сервіс, ролі
  github_oidc.tf       роль для GitHub Actions
  budget.tf            бюджет зі сповіщенням на пошту
.github/workflows/     deploy.yml: push -> збірка -> ECR -> ECS
```

## Як запустити

**Локально** (потрібен Docker):

```bash
docker compose up --build
```

Відкрити http://localhost:8000/docs. Дані зберігаються у volume і не зникають після `docker compose down`.

**В AWS** (потрібні AWS CLI та Terraform):

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # вписати свій github_repo і email
terraform init
terraform apply
```

Після цього в GitHub додати змінну `AWS_ROLE_ARN` (значення з `terraform output github_actions_role_arn`)
і зробити `git push`. Видалити все: `terraform destroy`.

## Що я виконав

1. Застосунок у контейнері та локальний запуск через compose
2. Розгортання в AWS через Terraform
3. Мережева ізоляція бази даних
4. Балансувальник навантаження
5. Автоматичний деплой з GitHub через OIDC
6. Swagger UI з документацією API (бонус)

## Для демонстрації

```bash
curl http://notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com/

for /l %i in (1,1,6) do @curl -s http://notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com/ & echo.

curl http://notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com/api/notes

git add . && git commit -m "demo" && git push
gh run watch
```

## Завдання 1: контейнер локально

```
cd C:\cloud-lab1
docker compose up --build -d
docker compose ps
docker volume ls
curl -X POST http://localhost:8000/api/notes -H "Content-Type: application/json" -d "{\"title\":\"test\"}"
docker compose down
docker compose up -d
curl http://localhost:8000/api/notes
docker compose down
```
## Автодеплой

```
git add .
git commit -m "demo change"
git push
gh run watch

curl http://notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com/
git log --oneline -1
```
## Завдання 4: балансування

```
for /l %i in (1,1,6) do @curl -s http://notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com/ & echo.
curl http://notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com/health
curl http://notes-api-alb-1940175042.eu-central-1.elb.amazonaws.com/health/db
```
## Завдання 2 і 3: що показати в AWS

```
aws ecs describe-services --cluster notes-api-cluster --services notes-api-service --query "services[0].[desiredCount,runningCount]"
aws ecr describe-images --repository-name notes-api --query "imageDetails[*].imageTags" --output text
aws rds describe-db-instances --query "DBInstances[0].[PubliclyAccessible,MultiAZ,BackupRetentionPeriod,StorageEncrypted]"
aws ec2 describe-security-groups --filters Name=group-name,Values=notes-api-db-sg --query "SecurityGroups[0].IpPermissions"
aws secretsmanager describe-secret --secret-id notes-api/database-url --query Name
aws logs tail /ecs/notes-api --since 10m
```
## Terraform і CI/CD

```
cd C:\cloud-lab1\terraform
terraform state list
terraform plan
aws iam get-role --role-name notes-api-github-actions --query "Role.AssumeRolePolicyDocument"
```

## Відкат

```
aws ecs list-task-definitions --family-prefix notes-api-app
aws ecs update-service --cluster notes-api-cluster --service notes-api-service --task-definition notes-api-app:<N>
```
## Destroy

```
cd C:\cloud-lab1\terraform
terraform destroy
```
