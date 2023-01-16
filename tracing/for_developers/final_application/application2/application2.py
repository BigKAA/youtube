import os
import random
import sys
import time

from flask import Flask, request, jsonify
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.wsgi import collect_request_attributes
from opentelemetry.propagate import extract
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, SpanExporter
from opentelemetry.semconv.trace import SpanAttributes

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

resource = Resource(attributes={
    SERVICE_NAME: "application2"
})


def select_processor() -> SpanExporter:
    """
    Конфигурация используемого экспортера через переменные среды окружения.
    Возможны два варианта:
    OpenTelemetry -> OTEL_EXPORTER_OTLP_ENDPOINT=http(s)://host:port
    Jaeger -> OTEL_EXPORTER_JAEGER_AGENT_HOST=host
              OTEL_EXPORTER_JAEGER_AGENT_PORT=port
    """
    if "OTEL_EXPORTER_OTLP_ENDPOINT" in os.environ:
        return OTLPSpanExporter()
    elif "OTEL_EXPORTER_JAEGER_AGENT_HOST" in os.environ \
            and "OTEL_EXPORTER_JAEGER_AGENT_PORT" in os.environ:
        return JaegerExporter()
    print("Not set exporter in env variable OTEL_EXPORTER_OTLP_ENDPOINT or"
          + " OTEL_EXPORTER_JAEGER_AGENT_HOST| OTEL_EXPORTER_JAEGER_AGENT_PORT]", file=sys.stderr)
    exit(1)


provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(select_processor())
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)


@app.route("/")
def root():
    return "Application 2"


@app.route("/api/v1/data")
def db_request_emulation():
    with tracer.start_as_current_span(
            "/api/v1/data",
            context=extract(request.headers),
            kind=trace.SpanKind.SERVER,
            attributes=collect_request_attributes(request.environ)
    ) as span:
        span.set_attribute("function", "db_request_emulation")
        span.set_attribute(SpanAttributes.HTTP_METHOD, "GET")

        # Посмотрим заголовки
        span.add_event(f"Headers \n {request.headers}")

        # generate 1-st delay and value
        delay: float = random.uniform(0.1, 0.9)
        span.add_event(f"1-s request, delay - {delay}")
        time.sleep(delay)
        data[0]['value'] = delay
        with tracer.start_as_current_span("/api/v1/data sub_request") as rspan:
            # generate 2-nd delay and value
            delay: float = random.uniform(0.1, 0.9)
            rspan.add_event(f"2-d request, delay - {delay}")
            time.sleep(delay)
            data[1]['value'] = delay
            return jsonify({'data': data})


if __name__ == "__main__":
    app.run(port=5000)
