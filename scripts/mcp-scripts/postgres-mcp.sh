#!/bin/bash

CONTAINER_NAME="postgres-mcp"

# 이미 실행 중인지 확인
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    # 실행 중이면 attach
    docker attach --no-stdin "$CONTAINER_NAME"
elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    # 중지된 컨테이너가 있으면 시작
    docker start -ai "$CONTAINER_NAME"
else
    # 없으면 새로 생성
    docker run -i --name "$CONTAINER_NAME" \
        -e DATABASE_URI \
        crystaldba/postgres-mcp \
        --access-mode=unrestricted
fi