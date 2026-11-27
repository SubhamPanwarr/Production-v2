# Stage 1: Build Java application
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /app

COPY pom.xml .
COPY src ./src

RUN mvn -B -ntp -Dmaven.test.skip=true clean package

# Stage 2: Tomcat runtime
FROM tomcat:11.0-jre17-temurin

# Create non-root application user and prepare directories
RUN rm -rf /usr/local/tomcat/webapps/* \
    && groupadd --system --gid 10001 appgroup \
    && useradd --system --uid 10001 --gid appgroup \
       --no-create-home appuser \
    && mkdir -p /usr/local/tomcat/conf/Catalina/localhost \
    && chown -R 10001:10001 \
       /usr/local/tomcat/webapps \
       /usr/local/tomcat/logs \
       /usr/local/tomcat/temp \
       /usr/local/tomcat/work \
       /usr/local/tomcat/conf/Catalina

# Deploy the Java WAR
COPY --from=build --chown=10001:10001 \
    /app/target/dptweb-1.0.war \
    /usr/local/tomcat/webapps/ROOT.war

USER 10001:10001

EXPOSE 8080

CMD ["catalina.sh", "run"]
