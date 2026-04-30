FROM eclipse-temurin:25-jdk-jammy

WORKDIR /build

# Install git and other build dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Clone the Paper repository
COPY . /build

# Make gradlew executable
RUN chmod +x gradlew

# Apply patches and build the project
RUN ./gradlew applyPatches createPaperclipJar

# Output stage
FROM eclipse-temurin:25-jre-jammy

WORKDIR /papermc

# Copy the compiled JAR from the build stage
COPY --from=0 /build/paper-server/build/libs/paperclip-*.jar ./server.jar

# Expose the Minecraft port
EXPOSE 25565

# Set the Java memory options
ENV JVM_OPTS="-Xms2G -Xmx2G"

# Run Paper server
ENTRYPOINT ["java", "-server"]
CMD ["-Xms2G", "-Xmx2G", "-XX:+UseG1GC", "-XX:+UnlockExperimentalVMOptions", "-XX:G1NewCollectionHeapPercent=20", "-XX:G1MaxNewGenPercent=30", "-XX:G1HeapRegionSize=16M", "-XX:G1HeapWastePercent=5", "-XX:G1MixedGCCountTarget=4", "-XX:InitiatingHeapOccupancyPercent=15", "-XX:G1MixedGCLiveThresholdPercent=90", "-XX:G1RSetUpdatingPauseTimePercent=5", "-XX:SurvivorRatio=32", "-XX:+PerfDisableSharedMem", "-XX:MaxTenuringThreshold=1", "-Dusing.aikars.flags=true", "-jar", "server.jar", "nogui"]
