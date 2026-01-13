# ISO Hackathon

Build bootable ISOs for Fedora-based distributions using image-builder and bootc.

## Prerequisites

- [just](https://github.com/casey/just) - command runner
- [podman](https://podman.io/) - container runtime
- Go toolchain (for building image-builder)
- osbuild and dependencies (for ISO generation)
- qemu (for booting ISOs)

## Quick Start

```bash
# List available targets
just

# Build a Bazzite ISO
just bazzite-iso

# Build a Kinoite ISO
just kinoite-iso

# Boot an ISO in QEMU
just bazzite-boot
just kinoite-boot
```

## Available Targets

| Target | Description |
|--------|-------------|
| `bazzite-image` | Build the Bazzite container image |
| `bazzite-iso` | Build Bazzite ISO (includes building image-builder and container image) |
| `bazzite-boot` | Boot Bazzite ISO in QEMU (4GB RAM, 2 CPUs) |
| `kinoite-image` | Build the Kinoite container image |
| `kinoite-iso` | Build Kinoite ISO (includes building image-builder and container image) |
| `kinoite-boot` | Boot Kinoite ISO in QEMU (4GB RAM, 2 CPUs) |
| `image-builder` | Build image-builder-cli from source with patched images library |

## Output

ISOs are output to target-specific directories under `output/`:

- `output/bazzite/` - Bazzite ISO
- `output/kinoite/` - Kinoite ISO

This allows building multiple ISOs in parallel.

## Project Structure

```
.
├── justfile                    # Build orchestration
├── bazzite/                    # Bazzite image
│   ├── Containerfile           # Container build definition
│   └── src/
│       └── flatpaks            # Flatpaks to include
├── kinoite/                    # Kinoite image
│   ├── Containerfile           # Container build definition
│   ├── regen-dracut.sh         # Initramfs regeneration script
│   └── src/
│       └── flatpaks            # Flatpaks to include
└── output/                     # Built ISOs (gitignored)
```

## How It Works

1. **image-builder**: Clones and builds [image-builder-cli](https://github.com/osbuild/image-builder-cli) with a patched images library from the `hackathon` branch.

2. **Container Image**: Builds a bootc-compatible container image for the target distribution with:
   - Live ISO support (dracut-live)
   - Anaconda installer
   - Pre-configured flatpaks
   - Distribution-specific customizations

3. **ISO Generation**: Uses image-builder to create a bootable ISO with:
   - The container image as the installer environment
   - A payload reference to the target distribution image

4. **Boot**: Uses QEMU to boot the generated ISO with 4GB RAM and 2 CPUs.

## Adding a New Target

1. Create a new directory (e.g., `my-distro/`)
2. Add a `Containerfile` that builds a bootc-compatible image
3. Add targets to `justfile`:

```just
# Build the my-distro container image
my-distro-image: (build-image "my-distro")

# Build my-distro ISO
my-distro-iso: (build-iso "my-distro" "registry.example.com/my-distro:latest")

# Boot my-distro ISO in QEMU
my-distro-boot: (boot-iso "my-distro")
```
