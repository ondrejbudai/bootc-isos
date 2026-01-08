# ISO Hackathon

Build bootable ISOs for Fedora-based distributions using image-builder and bootc.

## Prerequisites

- [just](https://github.com/casey/just) - command runner
- [podman](https://podman.io/) - container runtime
- Go toolchain (for native image-builder builds)

## Quick Start

```bash
# List available targets
just

# Build a Bazzite ISO
just bazzite-iso

# Build a Kinoite ISO
just kinoite-iso
```

## Available Targets

| Target | Description |
|--------|-------------|
| `bazzite-image` | Build the Bazzite installer container image |
| `bazzite-iso` | Build Bazzite ISO (includes building image-builder and container image) |
| `kinoite-image` | Build the Kinoite container image |
| `kinoite-iso` | Build Kinoite ISO (includes building image-builder and container image) |
| `image-builder` | Build image-builder-cli from source with patched images library |

## Configuration

The justfile supports the following variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `use_container` | `false` | Set to `true` to build using containerized image-builder |

Example:
```bash
just use_container=true bazzite-iso
```

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

## Adding a New Target

1. Create a new directory (e.g., `my-distro/`)
2. Add a `Containerfile` that builds a bootc-compatible image
3. Add targets to `justfile`:

```just
# Build the my-distro container image
my-distro-image: (build-image "my-distro")

# Build my-distro ISO
my-distro-iso: (build-iso "my-distro" "registry.example.com/my-distro:latest")
```
