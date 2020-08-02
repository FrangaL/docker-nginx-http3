#!/bin/bash

BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF=$(git rev-parse --short HEAD)
TAG=$(git tag)

echo "BUILD_DATE: ${BUILD_DATE}"
echo "VCS_REF: ${VCS_REF}"

printenv

docker build --build-arg BUILD_DATE=${BUILD_DATE} \
  --build-arg VCS_REF=${VCS_REF} \
  -t nginx:${TAG} .
