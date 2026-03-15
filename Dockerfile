FROM eclipse-temurin:21-jdk

RUN apt-get update && apt-get install -y git

WORKDIR /paper

COPY . .

RUN chmod +x gradlew
RUN ./gradlew applyPatches
RUN ./gradlew createReobfBundlerJar
