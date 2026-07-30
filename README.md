# GKID Kernel — personal build

A Generic Kernel Image (GKI) kernel for the **Poco X6 Pro (Duchamp)**, compatible with any device
running a **6.1.xx-android14** GKI kernel.

This is a fork of [ahmed-alnassif/GKI-Duchamp](https://github.com/ahmed-alnassif/GKI-Duchamp), which is
where all the kernel work, performance tuning and build tooling comes from. Upstream already ships
NTSync and DroidSpaces; this fork exists because I wanted three things set up differently for my own
device. If you don't specifically want those differences, **use upstream's builds** — they cover more
variants and are more widely tested.

## What's different here

### 1. NTSync: mainline driver, labelling done from userspace

`/dev/ntsync` has to be reachable by unprivileged apps or Wine/Proton can't use it. There are two
routes to that, and this fork takes the second one:

- **Upstream's route:** the WildKernels `ntsync_base.patch` includes an in-kernel step that labels the
  node `u:object_r:gpu_device:s0` and sets mode `0666` shortly after the driver registers. Self-contained
  — the kernel alone is enough.
- **This fork's route:** apply the ntsync driver **as merged in mainline Linux, unmodified**, and do the
  labelling from userspace. A companion module (`ntsync-policy`) declares its own `ntsync_device` type,
  `chcon`s the node to it and `chmod`s `0666` on every boot.

Both give you a working `/dev/ntsync` with the same file permissions and SELinux still **Enforcing**.
I prefer the second because it keeps the driver identical to upstream Linux (so mainline changes apply
cleanly) and keeps the labelling expressed as SELinux policy I can read and audit separately from GPU
access. That's a preference about where the wiring lives, not a claim that upstream's approach is
broken — it works fine, and it has a real advantage this one doesn't (see the warning below).

> ⚠️ **NTSync here is two pieces — flash both.** Because the labelling is deliberately *not* in the
> kernel, **the kernel alone will not grant app access.** You need `ntsync-policy.zip`, attached to
> every release. If `/data` is wiped or the module is removed, reinstall it.

### 2. KernelSU-Next is pinned

Upstream tracks the KSU-Next `dev` branch. This fork pins **`v3.3.0`** so the kernel side always matches
a known manager release — tracking `dev` once swept in a uapi change that broke root grant against the
stable manager. **Install the matching [KernelSU-Next v3.3.0
manager](https://github.com/KernelSU-Next/KernelSU-Next/releases/tag/v3.3.0)** (versionCode `33214`);
the kernel and manager versions must move together.

### 3. One variant, DroidSpaces always on

A single **KernelSU-Next** build with DroidSpaces compiled in — not a dispatch-time toggle here, since
it's the whole reason I build this. Vanilla / KernelSU / SukiSU-Ultra / ReSukiSU and the Compat variants
are **not built** in this fork; get those from upstream.

> 🛡️ **SuSFS is not shipped here.** It's incompatible with DroidSpaces at runtime — upstream's own note:
> *"If you must use SuSFS with DroidSpaces, ensure that 'HIDE SUS MOUNTS FOR ALL PROCESSES' is disabled
> in your SuSFS4KSU settings to avoid container boot failures."* Since DroidSpaces is always on here,
> leaving SuSFS out avoids shipping that combination. Upstream builds SuSFS variants if you want them.

## Everything else comes from upstream

Unchanged from [upstream](https://github.com/ahmed-alnassif/GKI-Duchamp#-key-features) — see their
README for the full list:

*   **⚡ Performance & efficiency:** 300Hz timer, MGLRU, ARM-optimized memory routines, zRAM with LZ4
    + writeback, schedutil/ondemand governors, mq-deadline for UFS 4.0, F2FS and ext4 tuning
*   **🌐 Network:** TCP BBRv3 + Westwood+, FQ, ECN, forced `TCP_NODELAY`, IPv6 NAT + IP Set
*   **🔋 Battery:** 1s freeze timeout, 500ms wakelock cap, minimized alarm/s2idle wakeups
*   **🧠 Scheduler & CPU:** tuned idle-core scan order, cache-friendly struct alignment
*   **🔒 Baseband Guard (BBG):** LSM blocking unauthorized writes to critical partitions
*   **🐳 DroidSpaces** configs and the SysV IPC KABI patch
*   **🔥 LTO:** ThinLTO / FullLTO / none, selectable at dispatch

## 📱 Compatibility

*   **Primary device:** Poco X6 Pro (codename `duchamp`)
*   **GKI requirement:** flashes on any device with a **6.1.xx-android14** kernel
    *(only tested on the Poco X6 Pro — exercise caution elsewhere)*

## ⬇️ Downloads & flashing

Grab the latest build from [Releases](https://github.com/Leb-Sun/GKI-Duchamp/releases). Each release
contains:

- the **kernel** AnyKernel3 zip (`…-KernelSU-Next+NTSync-Droidspaces.zip`), and
- **`ntsync-policy.zip`** — required for NTSync here, see above.

**Flashing:**
1. Flash the **kernel** zip from recovery.
2. Install **`ntsync-policy.zip`** as a module from your KernelSU-Next manager.
3. Reboot. `/dev/ntsync` should come up as `u:object_r:ntsync_device:s0`, mode `0666`, with
   `getenforce` still reporting **Enforcing**.

> **Release model:** every CI build is published as a **pre-release** — unblessed by design. A build is
> only promoted to *Latest* after I've flashed it and confirmed it works on my device. If you want the
> verified build, take **Latest**; pre-releases are candidates.

## 🙏 Credits & licenses

- **Upstream** — [ahmed-alnassif/GKI-Duchamp](https://github.com/ahmed-alnassif/GKI-Duchamp): the
  performance work, Baseband Guard, LTO support, DroidSpaces integration and the entire build harness.
  Kernel source: [ahmed-alnassif/GKI-Duchamp-6.1](https://github.com/ahmed-alnassif/GKI-Duchamp-6.1).
- **NTSync** — the driver is the upstream Linux kernel driver by **Elizabeth Figura** (CodeWeavers),
  merged into mainline; GPL-2.0, SPDX headers preserved.
- **DroidSpaces** — the SysV IPC KABI-padding patch is by
  **[nullptr-t-oss](https://github.com/nullptr-t-oss)**; the config set is by **ravindu644**.
- **Root** — [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next).
- The `ntsync-policy` module uses the **Magisk** module installer template (topjohnwu, GPL-3.0).

This repository (build scripts + patch set) is GPL-3.0 (see [`LICENSE`](/LICENSE)); the kernel sources
it builds remain GPL-2.0 per their own SPDX headers.
