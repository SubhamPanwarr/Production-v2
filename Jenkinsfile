
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 45, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    environment {
        CI_IMAGE = "production-v2-vote:ci-${BUILD_NUMBER}"
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '523881172609'
        ECR_REPOSITORY = 'production-app'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                sh '''
                    rm -f trivy-report.txt \
                          trivy-critical-report.txt \
                          ecr-image.txt
                '''
            }
        }

        stage('Verify Repository') {
            steps {
                sh '''
                    set -eu

                    test -d terraform
                    test -d kubernetes/voting-app
                    test -d application/voting-app

                    test -f application/voting-app/vote/app.py
                    test -f application/voting-app/vote/Dockerfile
                    test -f sonar-project.properties

                    command -v docker
                    command -v trivy
                    command -v aws

                    echo "Repository validation passed"
                    git log -1 --oneline
                '''
            }
        }

        stage('Python Syntax Check') {
            steps {
                sh '''
                    set -eu

                    python3 -m py_compile \
                      application/voting-app/vote/app.py

                    echo "Python syntax validation passed"
                '''
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    set -eu

                    docker build \
                      --target final \
                      -t "$CI_IMAGE" \
                      application/voting-app/vote

                    echo "Docker image built successfully"
                '''
            }
        }

        stage('Application Smoke Test') {
            steps {
                sh '''
                    set -eu

                    docker run --rm \
                      --network none \
                      --entrypoint python \
                      "$CI_IMAGE" \
                      -c "from app import app; response = app.test_client().get('/'); assert response.status_code == 200; assert b'Cats' in response.data; assert b'Dogs' in response.data; print('Vote smoke test passed')"
                '''
            }
        }

        stage('SonarQube Cloud Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarScannerCLI'

                    withSonarQubeEnv('SonarQube') {
                        withEnv([
                            "SONAR_SCANNER_HOME=${scannerHome}"
                        ]) {
                            sh '''
                                set -eu
                                set +x

                                export SONAR_TOKEN="$SONAR_AUTH_TOKEN"

                                "$SONAR_SCANNER_HOME/bin/sonar-scanner"
                            '''
                        }
                    }
                }
            }
        }

        stage('Trivy Image Vulnerability Scan') {
            steps {
                sh '''
                    set -eu

                    echo "Starting Trivy vulnerability scan..."
                    echo "Image: $CI_IMAGE"

                    docker image inspect "$CI_IMAGE" > /dev/null

                    trivy image \
                      --scanners vuln \
                      --image-src docker \
                      --severity HIGH,CRITICAL \
                      --parallel 2 \
                      --timeout 15m \
                      --exit-code 0 \
                      --no-progress \
                      --format table \
                      --output trivy-report.txt \
                      "$CI_IMAGE"

                    echo "Trivy vulnerability report generated."

                    sed -n '1,100p' trivy-report.txt
                '''

                archiveArtifacts(
                    artifacts: 'trivy-report.txt',
                    allowEmptyArchive: false
                )
            }
        }

        stage('Trivy CRITICAL Security Gate') {
            steps {
                sh '''
                    set -eu

                    echo "Checking for CRITICAL vulnerabilities..."

                    trivy image \
                      --scanners vuln \
                      --image-src docker \
                      --severity CRITICAL \
                      --parallel 2 \
                      --timeout 15m \
                      --exit-code 1 \
                      --no-progress \
                      --format table \
                      --output trivy-critical-report.txt \
                      "$CI_IMAGE"

                    echo "Security gate passed."
                    echo "No CRITICAL vulnerabilities detected."
                '''
            }

            post {
                always {
                    archiveArtifacts(
                        artifacts: 'trivy-critical-report.txt',
                        allowEmptyArchive: true
                    )
                }
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-ecr-push'
                ]]) {
                    sh '''
                        set -eu
                        set +x

                        echo "Checking AWS identity..."

                        ACTUAL_ACCOUNT_ID=$(
                            aws sts get-caller-identity \
                              --query Account \
                              --output text
                        )

                        if [ "$ACTUAL_ACCOUNT_ID" != "$AWS_ACCOUNT_ID" ]; then
                            echo "ERROR: Unexpected AWS account."
                            exit 1
                        fi

                        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                        ECR_URI="${ECR_REGISTRY}/${ECR_REPOSITORY}"

                        COMMIT_SHA=$(git rev-parse --short=7 HEAD)

                        IMAGE_TAG="ci-${BUILD_NUMBER}-${COMMIT_SHA}"

                        ECR_IMAGE="${ECR_URI}:${IMAGE_TAG}"

                        echo "Checking ECR repository..."

                        aws ecr describe-repositories \
                          --repository-names "$ECR_REPOSITORY" \
                          --region "$AWS_REGION" > /dev/null

                        echo "Logging in to Amazon ECR..."

                        aws ecr get-login-password \
                          --region "$AWS_REGION" |
                          docker login \
                            --username AWS \
                            --password-stdin "$ECR_REGISTRY"

                        trap 'docker logout "$ECR_REGISTRY" >/dev/null 2>&1 || true; docker image rm "$ECR_IMAGE" >/dev/null 2>&1 || true' EXIT

                        echo "Tagging Docker image..."

                        docker tag "$CI_IMAGE" "$ECR_IMAGE"

                        echo "Pushing Docker image to ECR..."

                        docker push "$ECR_IMAGE"

                        echo "Verifying uploaded image..."

                        aws ecr describe-images \
                          --repository-name "$ECR_REPOSITORY" \
                          --image-ids imageTag="$IMAGE_TAG" \
                          --region "$AWS_REGION" \
                          --query 'imageDetails[0].imageDigest' \
                          --output text

                        printf '%s\\n' "$ECR_IMAGE" > ecr-image.txt

                        echo "ECR image push completed."
                        echo "Image: $ECR_IMAGE"
                    '''
                }

                archiveArtifacts(
                    artifacts: 'ecr-image.txt',
                    allowEmptyArchive: false
                )
            }
        }
    }

    post {

        always {
            sh '''
                docker image rm "$CI_IMAGE" \
                  > /dev/null 2>&1 || true
            '''
        }

        success {
            echo 'Production-v2 CI pipeline completed successfully.'
        }

        failure {
            echo 'Production-v2 CI pipeline failed. Review console output.'
        }
    }
}

