#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  fontconfig openjdk-21-jre \
  docker.io git curl unzip ca-certificates

install -d -m 0755 /etc/apt/keyrings

curl -fsSL \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  -o /etc/apt/keyrings/jenkins-keyring.asc

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update
apt-get install -y jenkins

systemctl enable --now docker
usermod -aG docker jenkins

cd /tmp
curl -fsSL \
  https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
  -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install

systemctl enable jenkins
systemctl restart jenkins
