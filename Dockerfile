# Версія базового образу зафіксована (не latest). slim = без зайвих пакетів, bookworm = Debian 12.
FROM python:3.12.7-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 1) Залежності - окремим шаром ДО коду: поки requirements.txt не змінився, шар береться з кешу.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 2) Непривілейований користувач - процес НЕ працює від root.
RUN useradd --system --uid 10001 --no-create-home appuser

# 3) Код застосунку - останнім (змінюється найчастіше).
COPY app ./app

ARG GIT_SHA=dev
ENV APP_VERSION=${GIT_SHA}

USER appuser
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
