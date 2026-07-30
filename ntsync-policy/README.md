# ntsync SELinux policy

Companion KSU/Magisk module for the GKID kernel's built-in **ntsync** driver. It gives apps
(Wine/Proton/Winlator) access to `/dev/ntsync` while SELinux stays **Enforcing**.

## Why it's needed
The kernel ships the upstream ntsync driver unmodified, so `/dev/ntsync` comes up with the default
SELinux label `u:object_r:device:s0` and `0600 root:root` permissions — unprivileged apps can't open
it. This module grants that access from userspace, expressed as SELinux policy:

- **`sepolicy.rule`** defines a dedicated `ntsync_device` type and lets the app domains
  (`untrusted_app`, `untrusted_app_all`, `isolated_app`, `ephemeral_app`) use the char device. ntsync
  is an unprivileged, futex-like primitive meant to be app-accessible, so the grant is broad by design.
  To tighten it, trim the rule to `untrusted_app_all` only.
- **`post-fs-data.sh`** runs on every boot: it relabels the node to `u:object_r:ntsync_device:s0` (a
  userspace `chcon`) and sets mode `0666`. The driver requests `0666`, but Android `ueventd` clamps any
  `/dev` node without an explicit rule to `0600 root:root`, so the module re-asserts the mode.

`0666` matches how mainline Linux ships `/dev/ntsync`. Access stays gated by the `ntsync_device` type,
and SELinux remains Enforcing.

## Install
1. Open your root manager (KernelSU-Next / KernelSU / Magisk / SukiSU / APatch) → Modules →
   Install from storage → pick `ntsync-policy.zip`.
2. Reboot.

## Verify (after reboot)
```sh
getenforce                 # -> Enforcing
ls -lZ /dev/ntsync         # -> crw-rw-rw- ... u:object_r:ntsync_device:s0
```
A Wine/Winlator app can then open `/dev/ntsync`.
