// Jenkins Pipeline for GitHub (Multibranch Pipeline or "Pipeline script from SCM").
// Assumptions:
// - This Jenkinsfile is committed at the repo root.
// - Jenkins job is configured to pull from GitHub, so `checkout scm` works.
// - Local docker registry is available at localhost:8085 on the Jenkins agent running Docker.

def dockerRegistry = "localhost:8085"
def dockerImage = "papermc/paper"

// Keepalive wrapper to reduce chances of Jenkins durable-task heartbeat issues on long steps
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
      stage('Initialize') {
        echo "========================================="
        echo "Paper Build Started"
        echo "Job: ${env.JOB_NAME}"
        echo "Build Number: ${env.BUILD_NUMBER}"
        echo "Branch: ${env.BRANCH_NAME ?: 'n/a'}"
        echo "Workspace: ${env.WORKSPACE}"
        echo "========================================="
      }

      stage('Checkout') {
        // Provided by Multibranch Pipeline or "Pipeline script from SCM"
        checkout scm
      }

      stage('Validate Java / Gradle') {
        sh 'java -version'
        sh './gradlew --version'
      }

      stage('Clean') {
        runWithKeepAlive('gradle clean', './gradlew --no-daemon clean', 60)
      }

      stage('Apply Patches') {
        // Long/heavy step; retry helps if interrupted by transient issues
        retry(2) {
          runWithKeepAlive('gradle applyPatches', './gradlew --no-daemon --stacktrace applyPatches', 30)
        }
      }

      stage('Build API') {
        runWithKeepAlive('gradle paper-api:build', './gradlew --no-daemon --stacktrace paper-api:build', 60)
      }

      stage('Build Server') {
        runWithKeepAlive('gradle paper-server:build', './gradlew --no-daemon --stacktrace paper-server:build', 60)
      }

      stage('Create Paperclip JAR') {
        runWithKeepAlive('gradle createPaperclipJar', './gradlew --no-daemon --stacktrace createPaperclipJar', 60)
      }

      stage('Test') {
        runWithKeepAlive('gradle test', './gradlew --no-daemon --stacktrace test', 60)
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
        // Built-in step; doesn't require Workspace Cleanup plugin
        deleteDir()
      }
    }
  }
}
