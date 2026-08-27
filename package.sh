#!/usr/bin/env sh

set -eu

IMAGE=tailscale-arm32v5:latest
OUT_TAR="${1:-ts-legacy.tar}"

docker buildx build --platform linux/arm/v5 --provenance=false --sbom=false -t "$IMAGE" --load .

docker run --rm \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v "$(pwd)":/out \
	quay.io/skopeo/stable:latest \
	copy --format v2s2 \
	"docker-daemon:${IMAGE}" \
	"docker-archive:/out/${OUT_TAR}:latest"