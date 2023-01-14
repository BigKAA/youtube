FROM nginx:1.23.1
ADD https://github.com/open-telemetry/opentelemetry-cpp-contrib/releases/download/webserver%2Fv1.0.3/opentelemetry-webserver-sdk-x64-linux.tgz /opt
RUN tar -xzf /opt/opentelemetry-webserver-sdk-x64-linux.tgz -C /opt
RUN cd /opt/opentelemetry-webserver-sdk && ./install.sh
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/opentelemetry-webserver-sdk/sdk_lib/lib
