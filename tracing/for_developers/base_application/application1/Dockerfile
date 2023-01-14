FROM python:3.10

WORKDIR /app
ENV FLASK_APP=application1.py
ENV FLASK_RUN_HOST=0.0.0.0

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 5000
COPY application1.py .
COPY templates ./templates
CMD ["flask", "run"]
