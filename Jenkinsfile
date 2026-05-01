// Jenkins Pipeline (Scripted) using JDK25 from Jenkins "Tools" configuration.
//
// Prereqs in Jenkins:
// - Manage Jenkins -> Tools -> JDK installations -> add one named "JDK25"
// - Job is "Pipeline script from SCM" or Multibranch so `checkout scm` works (or keep git step if not)

def dockerRegistry = "localhost:8085"
def dockerImage    = "papermc/paper"

// Keepalive wrapper to reduce Jenkins durable-task heartbeat issues on long steps
def runWithKeepAlive(String label, String cmd, int keepAliveSeconds = 30) {
  sh """#!/usr/bin/env bash
set -e

echo "[${label}] starting..."

( while true; do
    echo "[keepalive] ${label} still running..."
    sleep ${keepAliveSeconds}
  done ) &
KA_PID=\$!

cleanup() {
  kill \${KA_PID} >/dev/null 2>&1 || true
}
trap cleanup EXIT

${cmd}

echo "[${label}] done."
"""
}

node {
  timeout(time: 2, unit: 'HOURS') {
    try {
      stage('Use JDK 25') {
        // Pull JDK25 from Jenkins tools and put it on PATH
        def jdkHome = tool name: 'JDK25', type: 'hudson.model.JDK'
        env.JAVA_HOME = jdkHome
        env.PATH = "${jdkHome}/bin:${env.PATH}"

        echo "JAVA_HOME=${env.JAVA_HOME}"
        sh 'java -version'
      }

      stage('Checkout') {
        // If this job is NOT "Pipeline from SCM", replace with:
        // git branch: 'main', url: 'https://github.com/<you>/<repo>.git'
        checkout scm
      }

      stage('Validate Gradle') {
        sh './gradlew --version'
      }

      stage('Clean') {
        runWithKeepAlive('gradle clean', './gradlew --no-daemon clean', 60)
      }

      stage('Apply Patches') {
        // Heavy/long step; retry helps if interrupted
        retry(2) {
          runWithKeepAlive(
            'gradle applyPatches',
            // Reduce resource spikes a bit to help Jenkins stability
            './gradlew --no-daemon --stacktrace --max-workers=1 -Dorg.gradle.jvmargs="-Xmx2g" applyPatches',
            30
          )
        }
      }

      stage('Build API') {
        runWithKeepAlive(
          'gradle paper-api:build',
          './gradlew --no-daemon --stacktrace --max-workers=1 -Dorg.gradle.jvmargs="-Xmx2g" paper-api:build',
          60
        )
      }

      stage('Build Server') {
        runWithKeepAlive(
          'gradle paper-server:build',
          './gradlew --no-daemon --stacktrace --max-workers=1 -Dorg.gradle.jvmargs="-Xmx2g" paper-server:build',
          60
        )
      }

      stage('Create Paperclip JAR') {
        runWithKeepAlive(
          'gradle createPaperclipJar',
          './gradlew --no-daemon --stacktrace --max-workers=1 -Dorg.gradle.jvmargs="-Xmx2g" createPaperclipJar',
          60
        )
      }

      stage('Test') {
        runWithKeepAlive(
          'gradle test',
          './gradlew --no-daemon --stacktrace --max-workers=1 -Dorg.gradle.jvmargs="-Xmx2g" test',
          60
        )
      }

      stage('Archive Artifacts') {
        archiveArtifacts artifacts: 'paper-server/build/libs/paperclip-*.jar', fingerprint: true
        archiveArtifacts artifacts: 'paper-api/build/libs/**/*.jar', fingerprint: true
      }

      stage('Docker Build') {
        runWithKeepAlive('docker build',
          """
docker build -t ${dockerRegistry}/${dockerImage}:latest .
docker tag ${dockerRegistry}/${dockerImage}:latest ${dockerRegistry}/${dockerImage}:build-${env.BUILD_NUMBER}
          """.trim(),
          60
        )
      }

      stage('Docker Push (local registry)') {
        runWithKeepAlive('docker push',
          """
docker push ${dockerRegistry}/${dockerImage}:latest
docker push ${dockerRegistry}/${dockerImage}:build-${env.BUILD_NUMBER}
          """.trim(),
          30
        )
      }

      stage('Done') {
        echo "========================================="
        echo "Build SUCCEEDED"
        echo "Images:"
        echo "  ${dockerRegistry}/${dockerImage}:latest"
        echo "  ${dockerRegistry}/${dockerImage}:build-${env.BUILD_NUMBER}"
        echo "========================================="
      }
    } finally {
      stage('Cleanup') {
        deleteDir()
      }
    }
  }
}
