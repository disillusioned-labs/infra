FROM python:3.13.15-alpine3.23

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install \
    --root-user-action=ignore \
    --no-cache-dir \
    --requirement /app/requirements.txt

RUN addgroup -S -g 10001 kuma-provisioner \
    && adduser -S -D -H -u 10001 -G kuma-provisioner kuma-provisioner

COPY --chown=kuma-provisioner:kuma-provisioner provision.py /app/provision.py

USER 10001:10001

ENTRYPOINT ["python", "/app/provision.py"]
