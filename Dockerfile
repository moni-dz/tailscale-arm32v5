FROM --platform=linux/arm/v5 busybox:stable
COPY out/tailscaled /usr/sbin/tailscaled
COPY out/tailscaled /usr/bin/tailscale
COPY start.sh /start.sh
ENTRYPOINT ["/bin/sh", "/start.sh"]
