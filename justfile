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
        git reset --hard cf20ed6a417c5e4dd195b34967cd2e4d5dc7272f
    else
        git clone https://github.com/osbuild/image-builder-cli.git
        cd image-builder-cli
        git reset --hard cf20ed6a417c5e4dd195b34967cd2e4d5dc7272f
    fi
    # Apply fix for /dev mount failure in privileged containers
    sed -i '/mount.*devtmpfs.*devtmpfs.*\/dev/,/return err/ s/return err/log.Printf("check: failed to mount \/dev: %v", err)/' pkg/setup/setup.go
    # if go is not in PATH, install via brew and use the full brew path
    if ! command -v go &> /dev/null; then
        if [ -d "/home/linuxbrew/.linuxbrew" ]; then
            GO_BIN="/home/linuxbrew/.linuxbrew/bin/go"
        else
            echo "go not found in PATH and /home/linuxbrew/.linuxbrew not found"
            exit 1
        fi
    else
        GO_BIN="go"
    fi
    $GO_BIN mod tidy
    $GO_BIN mod edit -replace github.com/osbuild/images=github.com/ondrejbudai/images@bootc-generic-iso-dev
    $GO_BIN get github.com/osbuild/blueprint@v1.22.0
    # GOPROXY=direct so we always fetch the latest bootc-generic-iso-dev branch
    GOPROXY=direct $GO_BIN mod tidy
    podman build --security-opt label=disable --security-opt seccomp=unconfined -t {{image-builder-dev}} .

iso-in-container target:
    #!/bin/bash
    set -euo pipefail
    just container {{target}}
    mkdir -p output

    PAYLOAD_FLAG="$(just _payload_ref_flag {{target}})"

    # Generate the osbuild manifest
    echo "Manifest generation step"
    podman run --rm --privileged \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        --entrypoint /usr/bin/image-builder \
        {{image-builder-dev}} \
        manifest --bootc-ref localhost/{{target}}-installer --bootc-default-fs ext4 $PAYLOAD_FLAG bootc-generic-iso \
        > output/manifest.json

    # Patch manifest to add remove-signatures to org.osbuild.skopeo stages
    echo "Patching manifest to remove signatures from skopeo stages"
    jq '(.pipelines[] | .stages[]? | select(.type == "org.osbuild.skopeo") | .options) += {"remove-signatures": true}' \
        output/manifest.json > output/manifest-patched.json

    echo "Image building step"
    podman run --rm --privileged \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./output:/output:Z \
        -i \
        --entrypoint /usr/bin/osbuild \
        {{image-builder-dev}} \
        --output-directory /output --export bootiso - < output/manifest-patched.json

    # Rename ISO
    echo "Renaming ISO..."
    REF="localhost/{{target}}-installer"
    # Extract VERSION_ID from os-release. We use /etc/os-release as the standard path.
    # Note: The image might not have 'jq' or other tools, so sourcing is safest.
    # We use --security-opt label=disable to avoid SELinux permission issues with shared libraries
    VERSION_ID=$(podman run --rm --security-opt label=disable "$REF" sh -c '. /etc/os-release && echo $VERSION_ID')
    # Extract architecture
    ARCH=$(podman run --rm --security-opt label=disable "$REF" uname -m)
    
    # Construct new filename
    # Format: bootc-image-name-version-bootc-generic-iso-arch.iso
    # We use {{target}} as the image name part (e.g., bluefin-lts)
    ISO_NAME="bootc-{{target}}-${VERSION_ID}-bootc-generic-iso-${ARCH}.iso"
    
    echo "Moving output/bootiso/install.iso to output/${ISO_NAME}"
    mv output/bootiso/install.iso "output/${ISO_NAME}"
    echo "Build complete! ISO available at: output/${ISO_NAME}"

run-iso target:
    #!/usr/bin/bash
    set -eoux pipefail
    image_name="bootiso/install.iso"
    if [ ! -f "output/${image_name}" ]; then
         image_name=$(ls output/bootc-{{target}}*.iso 2>/dev/null | head -n 1 | xargs basename)
    fi



    # Determine which port to use
    port=8006;
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=always)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "BOOT_MODE=windows_secure")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/output/${image_name}":"/boot.iso")
    run_args+=(ghcr.io/qemus/qemu)
    xdg-open http://localhost:${port} &
    podman run "${run_args[@]}"
    echo "Connect to http://localhost:${port}"

dev target:
    just build-image-builder
    just iso-in-container {{target}}
    just run-iso {{target}}
