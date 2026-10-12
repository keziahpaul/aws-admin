# Stub agent image used to seed empty ECR repositories during bootstrap.
# The seed script builds ARM64 for AgentCore and AMD64 for the ECS Slack bot.
FROM python:3.12-slim

WORKDIR /app
COPY app.py /app/app.py

# Bedrock AgentCore runtime serves HTTP on 8080 (/ping, /invocations).
EXPOSE 8080

# No extra dependencies: uses only the Python standard library.
ENTRYPOINT ["python", "-u", "/app/app.py"]
