#!/bin/bash
set -e

docker build --build-arg TARGETARCH=amd64 -t kerjemanov/postgres-backup-s3 .
docker push kerjemanov/postgres-backup-s3