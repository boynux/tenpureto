#!/usr/bin/env bash

set -euo pipefail

export VENDOR="$1"

docker-compose build --pull
docker-compose run agent sh -c "fpm-cook --cache-dir /tmp/cache --pkg-dir /pkg"
