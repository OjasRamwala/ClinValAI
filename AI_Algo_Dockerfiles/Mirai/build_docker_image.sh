#!/bin/bash -e
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 730335476018.dkr.ecr.us-west-2.amazonaws.com
docker build -t 730335476018.dkr.ecr.us-west-2.amazonaws.com/risk-prediction/mirai:AIScoring . --platform linux/amd64
docker push 730335476018.dkr.ecr.us-west-2.amazonaws.com/risk-prediction/mirai:AIScoring