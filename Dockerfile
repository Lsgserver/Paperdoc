FROM eclipse-temurin:21-jdk AS builder

RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Source is cloned by Jenkins before docker build, so we just copy it in
COPY . .

RUN chmod +x ./gradlew && \
    ./gradlew build --no-daemon -x test

FROM eclipse-temurin:21-jre AS runtime

LABEL org.opencontainers.image.source="https://github.com/Lsgserver/Paperdoc"
LABEL description="PaperMC"

RUN useradd -m -s /bin/bash papermc

WORKDIR /papermc

COPY --from=builder /build/server/build/libs/*-all.jar papermc.jar

RUN chown -R papermc:papermc /papermc

USER papermc

# Velocity default proxy port
EXPOSE 25565

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD bash -c 'echo > /dev/tcp/localhost/25577' || exit 1

ENTRYPOINT ["java", \
    "-XX:+UseG1GC", \
    "-XX:G1HeapRegionSize=4M", \
    "-XX:+UnlockExperimentalVMOptions", \
    "-XX:+ParallelRefProcEnabled", \
    "-XX:+AlwaysPreTouch", \
    "-jar", "papermc.jar"]
    "-XX:+ParallelRefProcEnabled", \
    "-XX:+AlwaysPreTouch", \
    "-jar", "papermc.jar"]
