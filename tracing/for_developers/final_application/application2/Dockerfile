FROM python:3.10

WORKDIR /app

ENV FLASK_APP=application2.py
ENV FLASK_RUN_HOST=0.0.0.0

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt
EXPOSE 5000
COPY application2.py .
CMD ["flask", "run"]