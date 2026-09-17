// ============================================================
// Seclock CI/CD — build -> push to ECR (us-east-1) -> deploy to
// the on-prem-style kubeadm cluster in ap-south-1.
//
// Required Jenkins credentials (Manage Jenkins > Credentials):
//   1. "seclock-kubeconfig"  -> Secret file: kubeconfig for the
//      2-node cluster (copy from the control-plane node's
//      /etc/kubernetes/admin.conf, or a scoped user kubeconfig).
//
// AWS auth: if Jenkins itself runs on an EC2 instance, attach an
// IAM instance profile with ECR push/pull rights instead of
// storing static AWS keys — nothing else to configure below.
// If Jenkins is NOT on EC2, add an "aws-ecr-creds" Username/Password
// (or "AWS Credentials") entry and un-comment the withCredentials
// block in the "Login to ECR" stage.
// ============================================================

pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID  = '859925121963'                 // <-- replace with your AWS account ID
        AWS_REGION      = 'us-east-1'                     // ECR lives here (cluster is in ap-south-1)
        ECR_REPO        = 'fast-api'
        ECR_REGISTRY    = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG       = "${env.BUILD_NUMBER}"
        FULL_IMAGE      = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
        KUBECONFIG_CRED = 'seclock-kubeconfig'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
            }
        }

        stage('Login to ECR') {
            steps {
                // Instance-profile auth (default):
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} \
                    | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                """
                // Static-credentials alternative (Jenkins not on EC2) — uncomment:
                // withCredentials([usernamePassword(credentialsId: 'aws-ecr-creds',
                //         usernameVariable: 'AWS_ACCESS_KEY_ID',
                //         passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                //     sh """
                //         aws ecr get-login-password --region ${AWS_REGION} \
                //         | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                //     """
                // }
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${FULL_IMAGE}
                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPO}:latest
                    docker push ${FULL_IMAGE}
                    docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
                """
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: "${KUBECONFIG_CRED}", variable: 'KUBECONFIG')]) {
                    sh """
                        sed "s#__IMAGE__#${FULL_IMAGE}#" k8s/deployment.yaml > k8s/deployment.rendered.yaml

                        kubectl apply -f k8s/deployment.rendered.yaml
                        kubectl rollout status deployment/seclock --timeout=120s
                    """
                }
            }
        }
    }

    post {
        always {
            sh "docker image prune -f || true"
        }
        success {
            echo "Deployed ${FULL_IMAGE} to the cluster."
        }
        failure {
            echo 'Pipeline failed — check the stage logs above.'
        }
    }
}
