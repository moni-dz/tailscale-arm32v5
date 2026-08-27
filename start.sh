#!/bin/sh
# Entrypoint for the RouterOS tailscale container.
# tailscale (CLI) and tailscaled (daemon) are the same binary here -
# /usr/bin/tailscale is a symlink to /usr/sbin/tailscaled, which dispatches
# to CLI mode when argv[0] is "tailscale" (built with --box).
#
# Env vars (set via RouterOS /container envs, envlist attached to the
# container):
#   AUTH_KEY          tailscale auth key (tskey-auth-...)
#   ADVERTISE_ROUTES   comma-separated subnets to advertise, e.g. 192.168.88.0/24
#   CONTAINER_GATEWAY  container's default gateway IP; RouterOS container
#                      networking doesn't always push a default route, so
#                      it's added explicitly here
#   TAILSCALE_ARGS     extra flags appended to `tailscale up` as-is, e.g.
#                      "--accept-routes --advertise-exit-node"
set -eu

STATE_DIR=/var/lib/tailscale
SOCKET=/var/run/tailscale/tailscaled.sock

mkdir -p "$STATE_DIR" /var/run/tailscale

if [ -n "${CONTAINER_GATEWAY:-}" ]; then
	ip route replace default via "$CONTAINER_GATEWAY"
fi

# Required for subnet routes / exit-node relaying.
if [ -n "${ADVERTISE_ROUTES:-}" ] || printf '%s' "${TAILSCALE_ARGS:-}" | grep -q -- '--advertise-exit-node'; then
	sysctl -w net.ipv4.ip_forward=1 net.ipv6.conf.all.forwarding=1
fi

tailscaled \
	--state="$STATE_DIR/tailscaled.state" \
	--socket="$SOCKET" &
TAILSCALED_PID=$!

# Wait for the daemon's local API socket before driving it with the CLI.
while [ ! -S "$SOCKET" ]; do
	sleep 0.5
done

UP_ARGS="--authkey=${AUTH_KEY:-}"
[ -n "${ADVERTISE_ROUTES:-}" ] && UP_ARGS="$UP_ARGS --advertise-routes=$ADVERTISE_ROUTES"

# $TAILSCALE_ARGS is intentionally unquoted so it word-splits into separate flags.
tailscale --socket="$SOCKET" up $UP_ARGS ${TAILSCALE_ARGS:-}

wait "$TAILSCALED_PID"
