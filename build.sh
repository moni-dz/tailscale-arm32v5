#!/usr/bin/env sh

set -eu

TS_VERSION="${TS_VERSION:-$(git ls-remote --tags --refs https://github.com/tailscale/tailscale.git \
	| awk -F/ '{print $NF}' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)}"
mkdir -p "$(dirname "${OUT:-./out/tailscaled}")"
OUT_DIR="$(cd "$(dirname "${OUT:-./out/tailscaled}")" && pwd)"
OUT_NAME="$(basename "${OUT:-./out/tailscaled}")"

echo "Building tailscale ${TS_VERSION} -> ${OUT_DIR}/${OUT_NAME}"

docker run --rm -e MSYS_NO_PATHCONV=1 \
	-v "${OUT_DIR}:/out" \
	-e HOME=/tmp -e GOCACHE=/tmp/gocache -e GOMODCACHE=/tmp/gomodcache \
	golang:1.24-bookworm sh -c "
		set -eu
		git clone --branch '$TS_VERSION' --depth 1 https://github.com/tailscale/tailscale.git /src
		cd /src
		CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 GOTOOLCHAIN=auto \
			./build_dist.sh --box --strip -o /out/${OUT_NAME} ./cmd/tailscaled
		chmod +x /out/${OUT_NAME}
	"

echo "--- stripped size ---"
ls -la "${OUT_DIR}/${OUT_NAME}"

docker run --rm -v "${OUT_DIR}:/out" alpine:3.22 sh -c "
	apk add --no-cache upx file >/dev/null
	file /out/${OUT_NAME}
	upx --best --lzma /out/${OUT_NAME}
"

echo "--- final (upx-compressed) size ---"
ls -la "${OUT_DIR}/${OUT_NAME}"
