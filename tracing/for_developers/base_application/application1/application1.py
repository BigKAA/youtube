import os
import random
import time

import requests
from flask import Flask, render_template

app = Flask(__name__)


@app.route("/")
@app.route("/index.html")
def root():
    return render_template("index.html")


@app.route("/api/v1/base")
def base():
    resp = requests.get(f"{os.getenv('APP2')}/api/v1/data")
    # Добавим случайную задержку
    delay: float = random.uniform(0.1, 0.9)
    time.sleep(delay)
    return resp.json()


if __name__ == "__main__":
    app.run(host='0.0.0.0')
