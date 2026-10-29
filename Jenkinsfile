
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    environment {
        CI_IMAGE = "production-v2-vote:ci-${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
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
                        withEnv(["SONAR_SCANNER_HOME=${scannerHome}"]) {
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
    }

    post {
        always {
            sh '''
                docker image rm "$CI_IMAGE" \
                  2>/dev/null || true
            '''
        }

        success {
            echo 'Production-v2 CI pipeline completed successfully.'
        }

        failure {
            echo 'CI pipeline failed. Review console output.'
        }
    }
}

