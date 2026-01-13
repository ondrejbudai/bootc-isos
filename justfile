build target:
    podman build --cap-add sys_admin --security-opt label=disable -t {{target}}-installer ./{{target}}
