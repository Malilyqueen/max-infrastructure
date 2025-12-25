#!/bin/bash
set -e

cd /opt/max-infrastructure

git pull origin main

if [ ! -f ".env" ]; then
    echo "ERROR: .env not found"
    exit 1
fi

docker compose down
docker compose build --no-cache
docker compose up -d

sleep 10
docker compose ps
docker compose logs -f
