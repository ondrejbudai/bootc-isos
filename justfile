# ISO Hackathon Build Justfile

# Default target: list available recipes
default:
    @just --list

# Image-builder container image name
image_builder_image_name := "image-builder"

# Whether to use container for building (set to "true" to enable)
use_container := "false"

###############################################################################
# Generic parameterized targets
###############################################################################

# Build a container image for the specified target
[private]
build-image target:
    podman build --cap-add=SYS_ADMIN -t {{ target }} ./{{ target }}

# Build ISO for the specified target using image-builder
[private]
build-iso target payload_ref: image-builder (build-image target)
    #!/usr/bin/env bash
    set -exo pipefail
    
    mkdir -p output/{{ target }}
    
    if [ "{{ use_container }}" = "true" ]; then
        podman run --rm --privileged --security-opt label=disable \
            -v /var/lib/containers/storage:/var/lib/containers/storage \
            -v "$(pwd)/output/{{ target }}:/output" \
            {{ image_builder_image_name }} \
            build --bootc-ref localhost/{{ target }}:latest --bootc-default-fs ext4 --bootc-installer-payload-ref {{ payload_ref }} bootc-generic-iso
    else
        ./image-builder --output-dir output/{{ target }} build --bootc-ref localhost/{{ target }}:latest --bootc-default-fs ext4 --bootc-installer-payload-ref {{ payload_ref }} bootc-generic-iso
    fi

# Boot an ISO using QEMU (4GB RAM, 2 CPUs, 20GB ephemeral disk, no UEFI)
[private]
boot-iso target:
    #!/usr/bin/env bash
    set -exo pipefail
    iso=$(find output/{{ target }} -name "*.iso" | head -1)
    if [ -z "$iso" ]; then
        echo "No ISO found in output/{{ target }}/"
        exit 1
    fi
    qemu-system-x86_64 -m 4G -smp 2 -enable-kvm \
        -cdrom "$iso" \
        -drive if=virtio,format=raw,file.driver=null-co,file.size=20G

# Build image-builder-cli from source with patched images library
image-builder:
    #!/usr/bin/env bash
    set -exo pipefail
    
    # Clone image-builder-cli if not already present
    if [ ! -d "image-builder-cli" ]; then
        git clone https://github.com/osbuild/image-builder-cli.git
    fi
    
    if [ "{{ use_container }}" = "true" ]; then
        # Reset Containerfile to upstream and patch it for:
        # 1. Better layer caching (copy go.mod/go.sum first, then download deps)
        # 2. Apply hackathon replace
        git -C image-builder-cli checkout Containerfile
        
        # Replace "COPY . /build" with a two-stage copy for better caching
        sed -i 's|^COPY \. /build|# Copy go.mod/go.sum first for better layer caching\nCOPY go.mod go.sum /build/\nWORKDIR /build\nRUN go mod download\n\n# Apply hackathon patch and download replaced module\nRUN go mod edit -replace github.com/osbuild/images=github.com/ondrejbudai/images@hackathon \&\& GOPROXY=direct go mod tidy\n\n# Copy the rest of the source\nCOPY . /build|' image-builder-cli/Containerfile
        
        # Remove the duplicate WORKDIR /build that comes after
        sed -i '/^# Copy the rest of the source/{n;n;/^WORKDIR \/build$/d}' image-builder-cli/Containerfile
        
        # Build the full image-builder container with runtime dependencies
        podman build -t {{ image_builder_image_name }} ./image-builder-cli
    else
        # Native build
        cd image-builder-cli
        
        # Download dependencies using proxy first (faster, cached)
        go mod tidy
        
        # Replace osbuild/images with the hackathon branch
        go mod edit -replace github.com/osbuild/images=github.com/ondrejbudai/images@hackathon
        GOPROXY=direct go mod tidy
        
        # Build image-builder
        go build -o ../image-builder ./cmd/image-builder
    fi

###############################################################################
# Bazzite targets
###############################################################################

# Build the bazzite container image with podman
bazzite-image: (build-image "bazzite")

# Build bazzite ISO using image-builder with bootc-installer image type
bazzite-iso: (build-iso "bazzite" "ghcr.io/ublue-os/bazzite:latest")

# Boot bazzite ISO in QEMU
bazzite-boot: (boot-iso "bazzite")

###############################################################################
# Kinoite targets
###############################################################################

# Build the kinoite container image with podman
kinoite-image: (build-image "kinoite")

# Build kinoite ISO using image-builder with bootc-installer image type
kinoite-iso: (build-iso "kinoite" "quay.io/fedora-ostree-desktops/kinoite:43")

# Boot kinoite ISO in QEMU
kinoite-boot: (boot-iso "kinoite")
