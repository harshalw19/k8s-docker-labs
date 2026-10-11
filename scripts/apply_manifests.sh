#!/bin/bash
#aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 396982710430.dkr.ecr.us-east-1.amazonaws.com
kubectl run test --image=nginx
#kubectl apply -f /opt/k8s/deploy-tomcat.yaml
