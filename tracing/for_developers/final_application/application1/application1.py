import os
import random
import sys
import time

import requests
from flask import Flask, request, render_template
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.wsgi import collect_request_attributes
from opentelemetry.propagate import extract
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, SpanExporter
from opentelemetry.semconv.trace import SpanAttributes
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

app = Flask(__name__)

resource = Resource(attributes={
    SERVICE_NAME: "application1"
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
@app.route("/index.html")
def root():
    with tracer.start_as_current_span(
            "/",
            context=extract(request.headers),
            kind=trace.SpanKind.SERVER,
            attributes=collect_request_attributes(request.environ)
    ) as span:
        span.set_attribute("function", "root")
        span.set_attribute(SpanAttributes.HTTP_METHOD, "GET")

        span.add_event("The root method")
        # Посмотрим заголовки
        span.add_event(f"Headers \n {request.headers}")
        return render_template("index.html")


@app.route("/api/v1/base")
def base():
    with tracer.start_as_current_span(
            "/api/v1/base",
            context=extract(request.headers),
            kind=trace.SpanKind.SERVER,
            attributes=collect_request_attributes(request.environ)
    ) as span:
        span.set_attribute("function", "base")
        span.set_attribute(SpanAttributes.HTTP_METHOD, "GET")

        span.add_event("Before delay")

        # Добавим информацию о нашем трейсе в запрос ко второму сервису
        headers = {}
        TraceContextTextMapPropagator().inject(headers)

        # Пошлем запрос во второе приложение
        resp = requests.get(f"{os.getenv('APP2')}/api/v1/data", headers=headers)

        # Добавим случайную задержку
        delay: float = random.uniform(0.1, 0.9)
        span.add_event(f"Set delay - {delay}")
        time.sleep(delay)
        span.add_event("After delay")

        return resp.json()


if __name__ == "__main__":
    app.run(port=5000)
