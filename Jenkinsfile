pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 10, unit: 'MINUTES')
        skipDefaultCheckout(true)
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

                    echo "Checking Production-v2 repository"

                    test -d terraform
                    test -d kubernetes/voting-app
                    test -d application/voting-app

                    test -f kubernetes/voting-app/base/vote-deployment.yaml
                    test -f kubernetes/voting-app/canary/vote-canary-deployment.yaml
                    test -f kubernetes/voting-app/ingress/vote-ingress.yaml

                    echo "Repository structure validated"
                    git log -1 --oneline
                '''
            }
        }
    }

    post {
        success {
            echo 'Production-v2 initial pipeline passed.'
        }
        failure {
            echo 'Pipeline failed. Check the Jenkins console output.'
        }
    }
}
