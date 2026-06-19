# ntsync SELinux policy

Companion KSU/Magisk module for the GKID kernel's built-in **ntsync** driver. It grants apps
(Wine/Proton/Winlator) access to `/dev/ntsync` the correct way — **without** loosening SELinux.

## Why this exists
The ntsync driver in this kernel is pristine: the in-kernel relabel hack used by some forks
(`ntsync_fix_perms_worker` / `__vfs_setxattr_noperm`, which masqueraded the node as `gpu_device`)
was deliberately removed. So out of the box `/dev/ntsync` is labeled `u:object_r:device:s0` and
ordinary apps are denied. This module restores access cleanly:

- `sepolicy.rule` defines a **dedicated** `ntsync_device` SELinux type and allows app domains
  (`untrusted_app`, `untrusted_app_all`, `isolated_app`, `ephemeral_app`) to use the char device.
  This broad app grant is **by design** — ntsync is a futex-like unprivileged primitive meant to be
  world-accessible to apps, so a per-app allowlist would be overkill (and isn't feasible from a module
  anyway, since apps share the `untrusted_app` domain). For least privilege you can trim the rule to
  `untrusted_app_all` only.
- `post-fs-data.sh` relabels the node to `u:object_r:ntsync_device:s0` (a normal userspace
  `chcon` from root context — not an LSM bypass) **and** `chmod 0666`s it. The driver requests
  `.mode=0666`, but Android `ueventd` clamps any `/dev` node lacking an explicit ueventd.rc rule to
  `0600 root:root` — which would DAC-block unprivileged Wine before SELinux is even consulted. The
  `chmod` re-asserts the driver's intended mode from userspace.

`0666` here is **not** loosening: it's how mainline Linux ships `/dev/ntsync`, and access stays gated
by the dedicated `ntsync_device` type (only the allowed app domains can use it). SELinux stays
**Enforcing**. No GPU ioctl surface, no security masquerade.

## Install (KernelSU-Next)
1. Open the **KernelSU-Next** manager → Modules → Install from storage → pick `ntsync-policy-v2.zip`.
2. Reboot.

Also installs under Magisk / KernelSU / SukiSU / APatch (standard Magisk module format).

## Verify (after reboot)
```sh
getenforce                 # -> Enforcing
ls -lZ /dev/ntsync         # -> crw-rw-rw- ... u:object_r:ntsync_device:s0
```
Then a Wine/Winlator app should be able to open `/dev/ntsync`.

## Rebuild the flashable zip
From this directory:
```sh
zip -r9 ../ntsync-policy-v2.zip . -x '*.zip'
```
(Zip the folder *contents* so `module.prop` sits at the archive root, not under `ntsync-policy/`.)
