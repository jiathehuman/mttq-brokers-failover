FROM python:3.9-alpine

RUN pip install paho-mqtt

RUN mkdir -p /health-status

COPY health-checker.py /app/health-checker.py

RUN chmod +x /app/health-checker.py

WORKDIR /app

CMD ["python", "health-checker.py"]