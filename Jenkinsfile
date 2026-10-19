pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        KUBECONFIG = '/etc/rancher/k3s/k3s.yaml'
        DOCKER_CONFIG = "${WORKSPACE}/.docker-ci"
    }

    stages {
        stage('Validation') {
            steps {
                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short=12 HEAD',
                        returnStdout: true
                    ).trim() + "-${env.BUILD_NUMBER}"
                }
                sh '''
                    bash -n scripts/deploy.sh scripts/smoke.sh
                    helm lint charts-databases
                    helm lint charts -f charts/values-exam.yaml -f charts/values-cast.yaml
                    helm lint charts -f charts/values-exam.yaml -f charts/values-movie.yaml
                '''
            }
        }

        stage('Construction des images') {
            steps {
                sh '''
                    mkdir -p "$DOCKER_CONFIG"
                    chmod 700 "$DOCKER_CONFIG"
                    docker compose -f docker-compose.yml -f docker-compose.ci.yml \
                      build movie_service cast_service
                '''
            }
        }

        stage('Publication Docker Hub') {
            when { branch 'master' }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_TOKEN'
                )]) {
                    sh '''
                        set +x
                        printf '%s' "$DOCKER_TOKEN" |
                          docker login -u "$DOCKER_USER" --password-stdin
                        docker compose -f docker-compose.yml -f docker-compose.ci.yml \
                          push movie_service cast_service
                    '''
                }
            }
        }

        stage('Dev') {
            when { branch 'master' }
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    sh './scripts/deploy.sh dev "$IMAGE_TAG"'
                    sh './scripts/smoke.sh dev'
                }
            }
        }

        stage('QA') {
            when { branch 'master' }
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    sh './scripts/deploy.sh qa "$IMAGE_TAG"'
                    sh './scripts/smoke.sh qa'
                }
            }
        }

        stage('Staging') {
            when { branch 'master' }
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    sh './scripts/deploy.sh staging "$IMAGE_TAG"'
                    sh './scripts/smoke.sh staging'
                }
            }
        }

        stage('Production manuelle') {
            when {
                beforeInput true
                branch 'master'
            }
            options {
                timeout(time: 30, unit: 'MINUTES')
            }
            input {
                message 'Déployer cette version en production ?'
                ok 'Déployer'
                submitter 'alouania'
            }
            steps {
                sh './scripts/deploy.sh prod "$IMAGE_TAG"'
                sh './scripts/smoke.sh prod'
            }
        }
    }

    post {
        always {
            sh 'rm -rf -- "$DOCKER_CONFIG"'
        }
    }
}
