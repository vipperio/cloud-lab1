# Покрокова інструкція: Лабораторна 1 (AWS + Terraform + GitHub Actions)

Орієнтовний час: 2–3 години. Вартість при швидкому проходженні й `terraform destroy` одразу після захисту: кілька доларів
(ALB ≈ $0.025/год, Fargate ×2 ≈ $0.02/год, RDS db.t3.micro — Free Tier/кредити). **Не залишайте ресурси на ніч без потреби.**

---
## Крок 0. Встановити інструменти

| Що | Windows (PowerShell, від адміна) | macOS (Homebrew) | Сайт |
|---|---|---|---|
| Git | `winget install Git.Git` | `brew install git` | https://git-scm.com/downloads |
| Docker Desktop | `winget install Docker.DockerDesktop` | `brew install --cask docker` | https://www.docker.com/products/docker-desktop |
| AWS CLI v2 | `winget install Amazon.AWSCLI` | `brew install awscli` | https://aws.amazon.com/cli/ |
| Terraform | `winget install Hashicorp.Terraform` | `brew install hashicorp/tap/terraform` | https://developer.hashicorp.com/terraform/install |
| VS Code (за бажанням) | `winget install Microsoft.VisualStudioCode` | `brew install --cask visual-studio-code` | https://code.visualstudio.com |

Windows: після Docker Desktop перезавантажте ПК, запустіть Docker Desktop і дочекайтесь зеленого статусу (потрібен WSL2).
Перевірка (у новому терміналі):
```bash
git --version && docker --version && aws --version && terraform -version
```

## Крок 1. Локальний запуск (Завдання 1, 2 бали)
Розпакуйте архів, відкрийте термінал у папці проєкту:
```bash
docker compose up --build
```
Відкрийте http://localhost:8000/docs → створіть нотатку через POST `/api/notes`.
Перевірка volume (дані переживають down):
```bash
docker compose down
docker compose up -d
curl http://localhost:8000/api/notes     # нотатка на місці
```
Для скріншотів/захисту: `docker compose ps`, `docker volume ls`.
Повне очищення (з видаленням даних): `docker compose down -v`.

## Крок 2. Репозиторій GitHub
1. Створіть акаунт на https://github.com, потім **новий порожній публічний репозиторій** (напр. `cloud-lab1`), без README.
2. У папці проєкту:
```bash
git init -b main
git add .
git commit -m "Lab 1: initial"
git remote add origin https://github.com/<USERNAME>/<REPO>.git
git push -u origin main
```
(GitHub попросить авторизацію через браузер або Personal Access Token.)
Перша push запустить workflow — він упаде (AWS ще не налаштований). Це нормально.

## Крок 3. Акаунт AWS
1. Зареєструйтесь на https://aws.amazon.com/free (потрібна банківська картка; спишуть і поверне ~$1 для перевірки).
2. **MFA для root:** Console → правий верхній кут → Security credentials → Assign MFA device (Google Authenticator / Authy).
3. **IAM-користувач (не root):** IAM → Users → Create user (напр. `terraform-admin`) →
   Attach policies directly → `AdministratorAccess` → Create. Потім користувач → Security credentials → **Create access key** →
   тип "Command Line Interface" → збережіть Access key ID і Secret.
   Також увімкніть MFA і для нього.
4. Для бюджету: від root один раз увімкніть доступ IAM до Billing: Account (меню справа зверху) →
   *IAM user and role access to Billing information* → Activate IAM Access.
5. Налаштуйте CLI:
```bash
aws configure
# Access key ID / Secret: з кроку 3 | Default region: eu-central-1 | Output: json
aws sts get-caller-identity       # має показати ваш IAM-користувач, а НЕ root
```
> Ключі IAM-користувача потрібні лише вашому ноутбуку для запуску Terraform. CI/CD ключів не має — він працює через OIDC.

## Крок 4. Terraform apply (Завдання 2–4, 7 балів разом із 1)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars      # Windows: copy terraform.tfvars.example terraform.tfvars
# відкрийте terraform.tfvars і впишіть github_repo = "USERNAME/REPO" та свій email
terraform init
terraform plan
terraform apply          # введіть yes; ~8-12 хв (найдовше RDS)
```
Виведе `app_url`, `github_actions_role_arn` тощо. Запишіть їх: `terraform output`.
Одразу прийде лист від AWS про підписку на сповіщення бюджету — підтвердіть.

На цьому етапі сервіс ще не працює (в ECR немає образу) — ECS буде безуспішно пробувати завантажити тег `initial`.
Це очікувано: образ збере CI/CD.

## Крок 5. Підключити CI/CD (Завдання 5)
1. GitHub → ваш репозиторій → Settings → Secrets and variables → Actions → вкладка **Variables** → New repository variable:
   - Name: `AWS_ROLE_ARN`, Value: значення `terraform output github_actions_role_arn`
   (це не секрет, просто ARN ролі.)
2. Запустіть workflow: Actions → "Deploy to AWS" → Run workflow на останньому запуску (Re-run all jobs),
   або порожній коміт: `git commit --allow-empty -m "deploy" && git push`.
3. Дочекайтесь зеленої позначки (~4–6 хв, є очікування стабільності сервісу).
4. Перевірте: `curl $(terraform output -raw app_url)` → має повернути `version` = хеш вашого коміту.
   Swagger: `<app_url>/docs`.
5. Створіть нотатку через Swagger і перевірте `/health/db` та `/api/notes`.

## Крок 6. Підготовка до демонстрації на захисті
**Зміна коду → автодеплой.** Наприклад, у `app/main.py` змініть поле `service` у `root()` на інший рядок, потім:
```bash
git add . && git commit -m "change greeting" && git push
```
Покажіть Actions → зелений запуск → оновіть `<app_url>/` — змінився `version` (новий SHA) і текст.

**Дані в БД.** База у приватній підмережі, прямого доступу ззовні немає — це вимога. Показати дані можна через API
(`/api/notes`) або у консолі AWS: RDS → ваша база (видно `Publicly accessible: No`, приватні підмережі).

**Що відкрити на захисті:** AWS Console → VPC (підмережі, route tables), EC2 → Security groups (правила "від SG"),
EC2 → Load balancers (health check), ECS (cluster → service → tasks), ECR (теги = SHA), IAM (роль github-actions, trust policy),
Secrets Manager (секрет), CloudWatch Logs (`/ecs/notes-api`).

**Балансування:** оновіть `<app_url>/` кілька разів — поле `hostname` змінюється між двома контейнерами.
**Self-healing:** ECS → зупиніть одну задачу (Stop) → ALB продовжує відповідати, ECS запускає нову.

## Крок 7. Прибирання (обов'язково після захисту)
```bash
cd terraform
terraform destroy        # yes
```
Перевірте в консолі, що не лишилось: RDS, ALB, ECS cluster, NAT (його тут немає), Elastic IP, CloudWatch log group.
Бюджет теж видаляється Terraform-ом.

---
## Типові проблеми
| Симптом | Причина / рішення |
|---|---|
| `terraform apply`: `AccessDenied` / `UnauthorizedOperation` | у `aws configure` не той користувач або без AdministratorAccess |
| Budget: `AccessDenied` | не активовано доступ IAM до Billing (Крок 3.4) |
| `EntityAlreadyExists` для OIDC provider | у акаунті вже є провайдер GitHub. Видаліть його в IAM → Identity providers (якщо не використовується) або імпортуйте: `terraform import aws_iam_openid_connect_provider.github arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com` |
| `Could not assume role` у Actions | змінна `AWS_ROLE_ARN` не задана або репозиторій у `github_repo` вказаний інакше (регістр!) і гілка не `main` |
| Задачі ECS не стартують, `CannotPullContainerError` | образу ще немає — запустіть workflow (Крок 5) |
| ALB повертає 503 | задачі ще не пройшли health check; зачекайте 1–2 хв або дивіться ECS → Service → Events |
| RDS: помилка `engine_version` | `terraform apply` після заміни `"16"` на `"16.4"` (або іншу доступну в регіоні версію) |
| `docker compose` не стартує на Windows | Docker Desktop не запущений / не ввімкнений WSL2 |
