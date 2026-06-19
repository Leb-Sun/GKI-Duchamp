#!/system/bin/sh
# Restore /dev/ntsync's intended posture once it exists (driver is built-in, so the node is early):
#   - chcon: relabel to the dedicated SELinux type so app domains get MAC access (see sepolicy.rule).
#   - chmod: re-assert mode 0666. The driver requests .mode=0666, but Android ueventd clamps any /dev
#     node without an explicit ueventd.rc rule to 0600 root:root, which DAC-blocks unprivileged Wine.
#     0666 + the dedicated ntsync_device type + Enforcing keeps access gated by SELinux, not loosened.
if [ -e /dev/ntsync ]; then
	chcon u:object_r:ntsync_device:s0 /dev/ntsync
	chmod 0666 /dev/ntsync
fi
