// Jenkinsfile — CI/CD for a FastAPI app
// Flow: checkout -> venv/deps -> lint -> test -> build image -> push to ECR -> deploy to k8s
//
// Required Jenkins setup (see notes at bottom):
//   - Agent with: python3, docker, aws-cli v2, kubectl
//   - Credentials:
//       'aws-ecr-creds'   -> AWS Access Key ID / Secret (Username/Password credential type)
//       'kubeconfig-prod' -> Secret file credential containing your kubeconfig
//   - Jenkins Pipeline plugins: Docker Pipeline, Pipeline Utility Steps

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        AWS_REGION       = 'us-east-1'                                    // <-- change
        AWS_ACCOUNT_ID   = '859925121963'                                 // <-- change
        ECR_REPO         = 'fast-api'                                  // <-- change
        ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG        = "${env.BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        IMAGE_URI        = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

        K8S_NAMESPACE    = 'default'                                      // <-- change
        K8S_DEPLOYMENT   = 'fastapi-app'                                  // <-- change
        K8S_CONTAINER    = 'fastapi-app'                                  // <-- change
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python venv') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                    pip install pytest pytest-cov ruff httpx2
                '''
            }
        }

        stage('Lint') {
            steps {
                sh '''
                    . .venv/bin/activate
                    ruff check .
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    . .venv/bin/activate
                    pytest --cov=. --cov-report=xml --cov-report=term -v
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/junit*.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_URI} -t ${ECR_REGISTRY}/${ECR_REPO}:latest ."
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-ecr-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} \
                            | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        docker push ${IMAGE_URI}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-prod', variable: 'KUBECONFIG')]) {
                    sh '''
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                            ${K8S_CONTAINER}=${IMAGE_URI} \
                            -n ${K8S_NAMESPACE}

                        kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE} --timeout=120s
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Deployed ${IMAGE_URI} to ${K8S_NAMESPACE}/${K8S_DEPLOYMENT} successfully."
        }
        failure {
            echo "Pipeline failed at stage: ${env.STAGE_NAME}"
            // Hook up Slack/email notification here, e.g.:
            // slackSend(color: 'danger', message: "Build ${env.BUILD_NUMBER} failed: ${env.BUILD_URL}")
        }
        always {
            sh 'docker image prune -f || true'
            cleanWs()
        }
    }
}
