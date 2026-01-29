image-builder := "image-builder"
image-builder-dev := "image-builder-dev"

# Helper: returns "--bootc-installer-payload-ref <ref>" or "" if no payload_ref file
_payload_ref_flag target:
    @if [ -f "{{target}}/payload_ref" ]; then echo "--bootc-installer-payload-ref $(cat '{{target}}/payload_ref' | tr -d '[:space:]')"; fi

container target:
    podman build --cap-add sys_admin --security-opt label=disable -t {{target}}-installer ./{{target}}

iso target:
    {{image-builder}} build --bootc-ref localhost/{{target}}-installer --bootc-default-fs ext4 `just _payload_ref_flag {{target}}` bootc-generic-iso

# We need some patches that are not yet available upstream, so let's build a custom version.
build-image-builder:
    #!/bin/bash
    set -euo pipefail
    if [ -d image-builder-cli ]; then
        cd image-builder-cli
        git fetch origin
        git reset --hard origin/main
    else
        git clone https://github.com/osbuild/image-builder-cli.git
        cd image-builder-cli
    fi
    go mod tidy
    go mod edit -replace github.com/osbuild/images=github.com/ondrejbudai/images@bootc-generic-iso-dev
    # GOPROXY=direct so we always fetch the latest bootc-generic-iso-dev branch
    GOPROXY=direct go mod tidy
    podman build -t {{image-builder-dev}} .

iso-in-container target:
    mkdir -p output
    podman run --rm --privileged \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./output:/output:Z \
        {{image-builder-dev}} \
        build --output-dir /output --bootc-ref localhost/{{target}}-installer --bootc-default-fs ext4 `just _payload_ref_flag {{target}}` bootc-generic-iso

# Patch an ISO with console=ttyS0 for serial output testing
patch iso_path output_path:
    #!/bin/bash
    set -euo pipefail
    mkdir -p "$(dirname {{output_path}})"
    podman run --rm --privileged \
        -v "$(dirname "$(realpath {{iso_path}})")":/input:ro,Z \
        -v "$(dirname "$(realpath {{output_path}})")":/output:Z \
        quay.io/fedora/fedora:latest \
        bash -c "dnf install -y lorax && mkksiso -c 'console=ttyS0' /input/$(basename {{iso_path}}) /output/$(basename {{output_path}})"

# Boot an ISO in QEMU and verify it reaches a target
test-boot iso_path:
    #!/bin/bash
    set -euo pipefail
    # Enable KVM access if available
    sudo chmod 666 /dev/kvm 2>/dev/null || true
    python3 test/boot-smoke-test.py {{iso_path}} --timeout 600

# Test an ISO end-to-end: patch it, then boot it
test-iso iso_path:
    #!/bin/bash
    set -euo pipefail
    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT
    just patch {{iso_path}} "$TMPDIR/patched.iso"
    just test-boot "$TMPDIR/patched.iso"
