FROM openjdk:11.0.14.1-jdk
RUN mkdir -p /opt/gitflic/log && mkdir -p /opt/gitflic/config && mkdir -p /opt/gitflic/var

ADD gitflic.jar /opt/gitflic/gitflic.jar
WORKDIR /opt/gitflic
EXPOSE 8080 22
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar /opt/gitflic/gitflic.jar"]
