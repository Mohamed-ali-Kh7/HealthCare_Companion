# --- Build: compile the Spring Boot jar ---
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src
# Dependencies first: this layer stays cached while only the sources change
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q -DskipTests package

# --- Run: JRE only ---
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /src/target/*.jar app.jar
# Fits small containers (e.g. Render free plan, 512 MB)
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+UseSerialGC -Xss512k"
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
