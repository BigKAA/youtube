FROM openjdk:11.0.14.1-jdk
RUN mkdir -p /opt/gitflic/log && mkdir -p /opt/gitflic/config && mkdir -p /opt/gitflic/var

ADD gitflic.jar /opt/gitflic/gitflic.jar
ADD docker/default-config/application.properties /opt/gitflic/config/application.properties

WORKDIR /opt/gitflic
EXPOSE 8080 22

ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -Dspring.config.additional-location=/opt/gitflic/config/application.properties -jar /opt/gitflic/gitflic.jar"]
