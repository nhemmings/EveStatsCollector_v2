#!/usr/bin/env bash
set -euo pipefail

REGISTRY="192.168.0.68:5000"
IMAGE="$REGISTRY/evestatscollector"
REMOTE="evestats"
REMOTE_DIR="/opt/evestats"


step() { echo -e "\n→ $1"; }

step "Ensuring remote directory exists..."
ssh "$REMOTE" "mkdir -p $REMOTE_DIR"

step "Syncing compose files..."
echo "docker-compose.prod.yml"
scp "docker-compose.prod.yml" "${REMOTE}:${REMOTE_DIR}/docker-compose.yml"
echo ".env.prod"
scp ".env.prod" "${REMOTE}:${REMOTE_DIR}/.env"
echo "librechat.yaml"
scp "librechat.yaml" "${REMOTE}:${REMOTE_DIR}/librechat.yaml"
echo "Dockerfile.librechat"
scp "Dockerfile.librechat" "${REMOTE}:${REMOTE_DIR}/Dockerfile.librechat"

step "Ensuring registry is up..."
ssh "$REMOTE" "cd $REMOTE_DIR && docker compose up -d registry"

step "Waiting for registry to be ready..."
until curl -sf "http://$REGISTRY/v2/" > /dev/null 2>&1; do
    echo "  waiting..."
    sleep 2
done

step "Building image..."
docker build -t "${IMAGE}:latest" -f EveStatsCollector.App/Dockerfile .

step "Pushing to registry..."
docker push "${IMAGE}:latest"

step "Building librechat image..."
ssh "$REMOTE" "cd $REMOTE_DIR && docker compose build librechat"

step "Deploying full stack..."
ssh "$REMOTE" "cd $REMOTE_DIR && docker compose pull app && docker compose up -d"

echo -e "\n✓ Deployed successfully"