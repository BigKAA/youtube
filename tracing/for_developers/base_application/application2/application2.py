import random
import time

from flask import Flask, jsonify

app = Flask(__name__)

data = [
    {
        "id": 1,
        "name": "Delay 1",
        "value": 12.1,
    },
    {
        "id": 2,
        "name": "Delay 2",
        "value": 23.1,
    }
]


@app.route("/api/v1/data")
def db_request_emulation():
    # generate 1-st delay and value
    delay: float = random.uniform(0.1, 0.9)
    time.sleep(delay)
    data[0]['value'] = delay

    # generate 2-nd delay and value
    delay: float = random.uniform(0.1, 0.9)
    time.sleep(delay)
    data[1]['value'] = delay
    return jsonify({'data': data})


if __name__ == "__main__":
    app.run(host='0.0.0.0')
