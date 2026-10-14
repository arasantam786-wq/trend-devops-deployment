pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        IMAGE_REPO = 'desing96/trend-app'
    }

    stages {
        stage('Build Docker Image') {
            steps {
                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short=12 HEAD',
                        returnStdout: true
                    ).trim() + "-${env.BUILD_NUMBER}"
                }
                sh 'docker build -t "$IMAGE_REPO:$IMAGE_TAG" .'
            }
        }

        stage('Check Image') {
            steps {
                sh '''
                    docker run --rm "$IMAGE_REPO:$IMAGE_TAG" nginx -t
                    docker run --rm "$IMAGE_REPO:$IMAGE_TAG" \
                      sh -c 'test -s /usr/share/nginx/html/index.html'
                '''
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_TOKEN'
                )]) {
                    sh '''
                        set +x
                        export DOCKER_CONFIG="$(mktemp -d)"
                        trap 'rm -rf "$DOCKER_CONFIG"' EXIT
                        printf '%s' "$DOCKER_TOKEN" |
                          docker login -u "$DOCKER_USER" --password-stdin
                        docker push "$IMAGE_REPO:$IMAGE_TAG"
                    '''
                }
            }
        }
        stage('Deploy to EKS') {
            steps {
                sh '''
                    set -eu
                    export KUBECONFIG="$(mktemp)"
                    trap 'rm -f "$KUBECONFIG"' EXIT

                    aws eks update-kubeconfig                       --name trend-eks --region us-east-1

                    kubectl apply -f k8s/service.yaml

                    kubectl set image                       -f k8s/deployment.yaml                       trend-app="$IMAGE_REPO:$IMAGE_TAG"                       --local -o yaml |
                      kubectl apply -f -

                    kubectl rollout status                       deployment/trend-app -n trend --timeout=300s

                    kubectl get pods -n trend -o wide
                    kubectl get service trend-app -n trend
                '''
            }
        }

    }

    post {
        success {
            echo "Uploaded image: ${env.IMAGE_REPO}:${env.IMAGE_TAG}"
        }
        always {
            sh '''
                if [ -n "${IMAGE_TAG:-}" ]; then
                    docker image rm "$IMAGE_REPO:$IMAGE_TAG" || true
                fi
            '''
        }
    }
}
