# Universal Debian Installer

A small, network-based, bootable ISO for automatically installing Debian 13 on Proxmox VMs.

The initial goal is **Debian 13 only**. Other operating systems will be added later.

## 1. Project Goal

Create a bootable ISO that:

1. Boots a minimal Linux environment.
2. Initializes networking using DHCP.
3. Presents a simple terminal menu.
4. Allows selecting Debian 13.
5. Downloads the required Debian components over the network.
6. Partitions and formats the target disk.
7. Bootstraps Debian 13 directly onto the disk.
8. Installs a minimal server environment.
9. Configures hostname, networking, SSH and the Proxmox QEMU guest agent.
10. Installs a bootloader.
11. Reboots into the newly installed Debian system.

The ISO should **not contain the Debian installation media**.

Instead:

```text
                 Universal Installer ISO
                         │
                         ▼
                  Minimal Linux
                         │
                         ▼
                     Installer
                         │
                    Internet
                         │
                         ▼
                 Debian repositories
                         │
                         ▼
                    Target disk
```

## 2. Design Goals

### Primary goals

* Very low memory usage.
* Fast boot.
* No graphical interface.
* Simple terminal interaction.
* Network-based installation.
* Debian 13 only initially.
* x86_64/amd64 initially.
* UEFI initially.
* Proxmox as the primary target environment.
* Rust for the main installer.
* Bash for build and development tooling.
* C/C++ may be used where useful for low-level components.
* Minimal dependencies in the installer environment.

### Non-goals for v0.1

Do not initially implement:

* Multiple distributions.
* ARM.
* Wi-Fi.
* Complex networking.
* RAID.
* LVM.
* ZFS.
* Btrfs.
* Disk encryption.
* BIOS boot.
* Graphical UI.
* Configuration server.
* Automatic VM creation in Proxmox.
* Custom package manager.
* Custom filesystem implementations.

Keep the first version boring.

## 3. Target Environment

Initial target:

```text
Hypervisor:       Proxmox VE
Architecture:     amd64
Boot:             UEFI
Network:          Ethernet / virtual NIC
Network config:   DHCP
Disk:             /dev/vda
Filesystem:       ext4
Partition table:  GPT
```

Example VM:

```text
CPU:       2 cores
RAM:       512 MB - 1 GB
Disk:      8 GB+
Network:   VirtIO
Firmware:  OVMF (UEFI)
```

The installer should eventually be comfortable running with only a few hundred MB of RAM.

## 4. High-Level Architecture

```text
┌─────────────────────────────────────┐
│       universal-installer.iso       │
│                                     │
│  ┌───────────────┐                  │
│  │ Linux kernel  │                  │
│  └───────┬───────┘                  │
│          │                          │
│  ┌───────▼───────┐                  │
│  │   initramfs   │                  │
│  │               │                  │
│  │   BusyBox     │                  │
│  │   Installer   │                  │
│  └───────┬───────┘                  │
└──────────┼──────────────────────────┘
           │
           ▼
       Initialize
       networking
           │
           ▼
      Simple menu
           │
           ▼
      Debian backend
           │
     ┌─────┴─────┐
     ▼           ▼
  Internet    Target disk
     │           │
     └─────┬─────┘
           ▼
     Debian 13 root
           │
           ▼
       bootloader
           │
           ▼
         reboot
```

## 5. Technology Stack

| Component          | Initial choice                 |
| ------------------ | ------------------------------ |
| Kernel             | Linux                          |
| Userspace          | BusyBox                        |
| Main application   | Rust                           |
| Build scripts      | Bash                           |
| Low-level code     | C/C++ only when justified      |
| Boot               | UEFI                           |
| Disk               | GPT                            |
| Root filesystem    | ext4                           |
| Network            | DHCP                           |
| Debian bootstrap   | `debootstrap` / Debian tooling |
| Package management | Debian `dpkg`/`apt`            |
| Initial UI         | terminal/stdin/stdout          |
| Configuration      | simple custom format initially |
| Target             | amd64                          |

The installer should use existing Debian components wherever practical instead of recreating Debian's package management system.

## 6. Repository Layout

Initial repository:

```text
universal-installer/
├── Cargo.toml
├── Cargo.lock
├── Makefile
├── README.md
├── LICENSE
│
├── src/
│   ├── main.rs
│   ├── menu.rs
│   ├── network.rs
│   ├── disk.rs
│   ├── filesystem.rs
│   ├── download.rs
│   └── debian/
│       ├── mod.rs
│       ├── bootstrap.rs
│       ├── packages.rs
│       ├── configure.rs
│       └── bootloader.rs
│
├── scripts/
│   ├── build-initramfs.sh
│   ├── build-iso.sh
│   └── prepare-rootfs.sh
│
├── rootfs/
│   ├── etc/
│   ├── bin/
│   └── ...
│
├── kernel/
│
├── build/
│
└── dist/
    └── universal-installer.iso
```

The directory structure can change as the project develops. Avoid creating abstractions before they are needed.

## 7. Development Strategy

Do not start by writing the Debian installer.

Build the project in small milestones.

### Milestone 1 — Boot

Goal:

```text
Proxmox
  ↓
ISO
  ↓
Linux kernel
  ↓
initramfs
  ↓
BusyBox
  ↓
Rust installer
```

The Rust program should simply print:

```text
Universal Installer
Hello from installer environment.
```

Then wait for input or reboot.

Success criterion:

> A VM can boot the custom ISO and execute the Rust program.

---

## 8. Milestone 2 — Networking

Add:

```text
NIC
 ↓
DHCP
 ↓
IP address
 ↓
DNS
 ↓
Internet
```

Initially use BusyBox/Linux facilities rather than implementing DHCP from scratch.

Expected output:

```text
Universal Installer

Initializing network...

DHCP successful.

IP:      192.168.x.x
Gateway: 192.168.x.x
DNS:     192.168.x.x

Network ready.
```

Do not support static IP configuration yet.

---

## 9. Milestone 3 — HTTPS Download

The installer must be able to securely download files.

Test with a small Debian resource first.

Requirements:

* HTTPS.
* Certificate validation.
* HTTP errors handled.
* Downloads streamed rather than loaded completely into RAM.
* Progress information.
* Temporary files.
* SHA-256 or equivalent integrity verification where appropriate.

Important:

> Never build the installer around blindly downloading and executing arbitrary content.

The installer should know exactly what it expects to download.

---

## 10. Milestone 4 — Disk Preparation

Initially support only:

```text
/dev/vda
```

The installer should:

1. Confirm the disk.
2. Warn that it will be erased.
3. Remove existing partition information.
4. Create GPT.
5. Create EFI System Partition.
6. Create root partition.
7. Format EFI as FAT32.
8. Format root as ext4.
9. Mount the target filesystem.

Target layout:

```text
/dev/vda
├── /dev/vda1   EFI   512 MiB
└── /dev/vda2   root  remaining space
```

Mounted as:

```text
/mnt/target
/mnt/target/boot/efi
```

Do not implement LVM, RAID, encryption or advanced filesystems yet.

---

## 11. Milestone 5 — Debian Bootstrap

This is the first major milestone.

The target should become a real Debian 13 filesystem without running the Debian graphical/interactive installer.

Conceptually:

```text
Installer environment
        │
        ├── partition disk
        │
        ├── mount /target
        │
        ├── obtain Debian bootstrap tools
        │
        └── bootstrap Debian 13
                    │
                    ▼
                /target
                    │
                    ├── /etc
                    ├── /usr
                    ├── /var
                    ├── /bin
                    └── ...
```

Investigate `debootstrap` as the initial mechanism.

Do not write a package manager.

Let Debian's own tools handle:

* package metadata
* dependencies
* package extraction
* package configuration
* maintainer scripts
* package database

Your installer should orchestrate the process.

---

## 12. Milestone 6 — Configure Debian

After bootstrapping:

### Hostname

Create:

```text
/etc/hostname
```

and appropriate `/etc/hosts` configuration.

### Filesystems

Generate:

```text
/etc/fstab
```

using UUIDs rather than assuming fixed device names.

### Timezone

Initially use a fixed default or make it configurable later.

### Locale

Use a sensible minimal locale.

### Networking

Initially configure DHCP.

### Users

Create one administrative user.

### SSH

Install and configure:

```text
openssh-server
```

The preferred authentication method should be an SSH public key.

Avoid password authentication as the primary mechanism.

### Proxmox guest agent

Install:

```text
qemu-guest-agent
```

and enable it.

---

## 13. Milestone 7 — Bootloader

Initially support UEFI only.

Install:

```text
GRUB
```

or another appropriate Debian-supported UEFI bootloader.

The final disk should look approximately like:

```text
GPT
│
├── EFI System Partition
│      └── EFI bootloader
│
└── ext4 root
       ├── /boot
       ├── /etc
       ├── /usr
       ├── /var
       └── ...
```

The installer should verify that the EFI bootloader was installed successfully before declaring success.

---

## 14. Milestone 8 — Reboot

At the end:

```text
Installation complete.

Remove the installer ISO and reboot.

Reboot now? [y/N]
```

On reboot:

```text
UEFI
 ↓
Debian bootloader
 ↓
Linux kernel
 ↓
systemd
 ↓
SSH
 ↓
qemu-guest-agent
 ↓
Debian 13
```

At this point the first usable version exists.

---

# 15. First Hard-Coded Configuration

Do not create a sophisticated configuration system yet.

The first version can use:

```text
OS: Debian 13
Architecture: amd64
Disk: /dev/vda
Network: DHCP
Filesystem: ext4
Hostname: debian01
User: admin
SSH: public key
```

The installer can ask only:

```text
Universal Installer

1. Install Debian 13
2. Reboot
3. Power off

Select:
```

Then:

```text
WARNING

The following disk will be completely erased:

    /dev/vda

Continue? [y/N]
```

This is enough for v0.1.

---

# 16. Configuration — Later

Once installation works reliably, introduce a configuration file.

Example:

```text
os=debian13
architecture=amd64

hostname=debian01

disk=/dev/vda

network=dhcp

user=admin

ssh_key=ssh-ed25519 AAAA...
```

Interactive mode:

```text
installer
```

Automated mode:

```text
installer --config /config/installer.conf
```

Eventually the configuration could be supplied through:

* ISO volume
* virtual CD-ROM
* HTTP
* HTTPS
* Proxmox-generated configuration
* kernel command line

The last three are especially interesting for future automation.

---

# 17. Installer Architecture

Keep OS-specific logic separate from generic installation functionality.

Generic functionality:

```text
Disk
Filesystem
Network
Download
Mount
Chroot
Process execution
File manipulation
Logging
```

Debian functionality:

```text
Debian repository
Debian bootstrap
Debian packages
Debian configuration
Debian kernel
Debian bootloader
```

Future structure:

```text
src/
├── core/
│   ├── disk.rs
│   ├── filesystem.rs
│   ├── network.rs
│   ├── download.rs
│   └── process.rs
│
└── os/
    ├── mod.rs
    ├── debian/
    ├── ubuntu/
    ├── fedora/
    ├── arch/
    └── freebsd/
```

Do not implement the future OS backends until Debian works.

---

# 18. Rust Responsibilities

Rust should eventually control the installation process.

For example:

```rust
fn main() -> Result<()> {
    initialize_environment()?;
    initialize_network()?;

    let selection = menu::choose_os()?;

    match selection {
        Os::Debian13 => debian::install()?,
    }

    reboot()?;

    Ok(())
}
```

The actual interfaces should evolve naturally.

Avoid creating elaborate traits and abstractions before there are multiple implementations.

---

# 19. Bash Responsibilities

Bash is useful for:

* building the initramfs
* copying BusyBox
* preparing the root filesystem
* building the ISO
* downloading/building a kernel
* running tests
* cleaning build artifacts
* creating test VMs

Example:

```text
scripts/
├── build-initramfs.sh
├── build-iso.sh
├── prepare-rootfs.sh
└── test.sh
```

The installer itself should not become a giant Bash script.

Use Bash for build/development automation and Rust for the actual application logic.

---

# 20. Memory Constraints

Target:

```text
Minimum practical RAM: ~256 MB
Preferred development RAM: 512 MB+
```

Avoid:

* desktop environments
* Python runtime
* Node.js
* large live distributions
* systemd in the installer environment
* unnecessary daemons
* loading entire ISO/package files into memory

Downloads should be streamed:

```text
network
  ↓
small buffer
  ↓
disk
```

rather than:

```text
network
  ↓
entire file in RAM
```

Measure actual memory usage before aggressively optimizing.

---

# 21. Security Requirements

This is an installer that can destroy disks, so safety matters.

Before destructive operations:

```text
WARNING: ALL DATA ON /dev/vda WILL BE DESTROYED.
```

Require explicit confirmation in interactive mode.

For unattended mode, require an explicit destructive-install flag/configuration.

Example:

```text
disk=/dev/vda
confirm_disk_wipe=true
```

Never silently choose an arbitrary disk.

Additional requirements:

* HTTPS for downloads.
* TLS certificate validation.
* Verify repository metadata.
* Verify downloaded artifacts.
* Do not execute untrusted downloaded files.
* Avoid embedding credentials in the ISO.
* SSH public keys are acceptable; private keys must never be stored in the installer.
* Log important installation actions.
* Make failures stop safely rather than continuing blindly.

---

# 22. Logging

The installer should produce readable logs:

```text
[ OK ] Initializing hardware
[ OK ] Starting network
[ OK ] DHCP
[ OK ] DNS
[ OK ] Checking Debian repository
[ OK ] Preparing /dev/vda
[ OK ] Creating GPT
[ OK ] Creating EFI partition
[ OK ] Creating root filesystem
[ OK ] Bootstrapping Debian
[ OK ] Installing kernel
[ OK ] Installing SSH
[ OK ] Installing QEMU guest agent
[ OK ] Installing bootloader
[ OK ] Writing configuration
[ OK ] Installation complete
```

Errors should be explicit:

```text
[FAIL] Unable to download Debian metadata

Reason:
TLS certificate verification failed.

Installation aborted.
```

Logs should ideally be saved somewhere in the installer environment and eventually copied to the installed system for troubleshooting.

---

# 23. Testing Strategy

Use disposable Proxmox VMs.

Never initially test against an important physical disk.

Test cases:

### Basic

```text
Fresh VM
→ boot ISO
→ install Debian
→ reboot
→ SSH
```

### Repeated

```text
install
→ destroy VM
→ create VM
→ install again
```

Repeat many times.

### Network failure

Disconnect networking during download.

Expected:

```text
Installation pauses/fails cleanly.
```

### Disk failure

Use an invalid/small disk.

Expected:

```text
Clear error.
No false "installation successful".
```

### Repository failure

Temporarily use an invalid repository.

Expected:

```text
Installation aborts safely.
```

### Reboot test

Verify the ISO is no longer required after installation.

---

# 24. Development Workflow

Use a dedicated development VM or machine.

Basic workflow:

```text
Edit Rust
    ↓
cargo build
    ↓
build initramfs
    ↓
build ISO
    ↓
upload ISO to Proxmox
    ↓
create disposable VM
    ↓
boot
    ↓
test
```

Eventually reduce this to:

```bash
make iso
```

and:

```bash
make test
```

The long-term goal is to make rebuilding the ISO trivial.

---

# 25. Versioning

Start with:

```text
v0.1.0
```

when the installer can:

```text
boot
→ network
→ install Debian 13
→ boot installed Debian
→ SSH
```

Possible later versions:

```text
v0.2
  Configuration file

v0.3
  Better error recovery

v0.4
  Automated/non-interactive installation

v0.5
  Installation customization

v0.6
  Debian version selection

v0.7
  Ubuntu backend

v0.8
  Fedora/RHEL-compatible backend

v0.9
  Arch backend

v1.0
  Stable multi-OS installer
```

The exact version numbers are not important; the milestones are.

---

# 26. Immediate Next Steps

Do these in order.

## Step 1

Prepare a Linux development environment with:

```text
Rust toolchain
Cargo
Git
Bash
BusyBox
Linux kernel
EFI/ISO building tools
QEMU tools
```

## Step 2

Create the repository:

```text
universal-installer/
```

## Step 3

Create a minimal Rust application that can run without the normal Linux userspace.

## Step 4

Build a minimal initramfs containing:

```text
Linux
BusyBox
Rust installer
init script
```

## Step 5

Build a bootable UEFI ISO.

## Step 6

Boot it in a disposable Proxmox VM.

## Step 7

Get DHCP working.

## Step 8

Get HTTPS downloading working.

## Step 9

Partition and format `/dev/vda`.

## Step 10

Manually prove the Debian 13 bootstrap process.

## Step 11

Move that process into Rust.

## Step 12

Install kernel + bootloader + SSH + QEMU guest agent.

## Step 13

Reboot into Debian.

## Step 14

Only then start improving the installer.

---

# 27. Definition of Success for v0.1

The project is successful when this works:

```text
┌───────────────────────────┐
│ Proxmox creates VM        │
│                           │
│ 2 CPU                     │
│ 512 MB RAM                │
│ 8+ GB disk                │
│ VirtIO network            │
│ UEFI                      │
└─────────────┬─────────────┘
              │
              ▼
      universal.iso
              │
              ▼
      minimal Linux
              │
              ▼
          DHCP
              │
              ▼
       Debian 13 selected
              │
              ▼
        disk formatted
              │
              ▼
      Debian downloaded
              │
              ▼
       Debian installed
              │
              ▼
       SSH configured
              │
              ▼
       QEMU agent ready
              │
              ▼
           reboot
              │
              ▼
        Debian 13 Server
```

The ultimate experience should eventually be as simple as:

```text
Create VM
Attach universal-installer.iso
Start VM
Choose Debian 13
Wait
Done
```

And the installer itself should remain a **small, fast, network-driven systems program**, rather than turning into another full Linux distribution.
