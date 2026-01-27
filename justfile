image-builder := "image-builder"
image-builder-dev := "image-builder-dev"

container target:
    podman build --cap-add sys_admin --security-opt label=disable -t {{target}}-installer ./{{target}}

iso target:
    {{image-builder}} build --bootc-ref localhost/{{target}}-installer --bootc-default-fs ext4 bootc-generic-iso

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
