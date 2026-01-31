# Container image based ISOs

This is an experiment showcasing building bootable ISO images from a container image. Building such an ISO is a 2-step process:

1) Building a container image that fulfills the required contract (more on that later)
2) Converting such an image to an ISO via [image-builder](https://github.com/osbuild/image-builder-cli) and the `bootc-generic-iso` type

## Design decisions

- The ISO uses El Torito configuration, shim, and GRUB2 configured to maximize compatibility. I.e., it is supposed to boot on all combinations of UEFI/legacy and CD/USB.
- Shim, GRUB2 and its configuration, kernel, and initramfs come from well-specified paths in the container.
- The ISO embeds the container converted to a squashfs archive.
- The user is responsible for configuring GRUB2, kernel, and initramfs so they can load the squashfs.

## Container-native ISO contract v0.1.0
This spec is inspired by the layout of Fedora bootc images and Fedora live ISO images.

- The kernel is expected to be in `/usr/lib/module/*/vmlinuz`. If there are multiple kernels, the behavior is unspecified. This is to be specified in a future version of this contract. The kernel is put in `/images/pxeboot/vmlinuz` in the ISO.
- The initramfs is expected to be next to the kernel with the filename `initramfs.img`. The initramfs is put in `/images/pxeboot/initrd.img`.
- The UEFI vendor is specified by a directory name in `/usr/lib/efi/shim/*/EFI/$VENDOR`. If there are multiple directories, the behaviour is unspecified. The `BOOT` directory is always ignored.
- Shim and grub2 EFI binaries (`shimx64.efi`, `mmx64.efi`, `gcdx64.efi`) are expected to be in `/boot/efi/EFI/$VENDOR`.
- GRUB2 modules are expected to be in `/usr/lib/grub/i386-pc`.
- Required executables are `podman`, `mksquashfs`, `xorriso`, `implantisomd5`, `grub2-mkimage`, and `python`.
- The container image is converted to a squashfs archive and put into `/LiveOS/squashfs.img` in the ISO.
- Additional configuration can be written into `/usr/lib/bootc-image-builder/iso.yaml` in YAML format. The file currently supports 2 top-level keys:
  - `label` (string): Label of the ISO
  - `grub2` (object): GRUB2 configuration, supports the following keys:
    - `default` (string): Default menu item
    - `timeout` (string): Default timeout (in seconds)
    - `entries` (array of objects): GRUB2 menu entries with the following keys (all are required):
      - `name` (string): Name of the entry
      - `linux` (string): Path to the kernel + kernel arguments (the path is always `/images/pxeboot/vmlinuz` in this version of this spec)
      - `initrd` (string): Path to the initramfs (the path is always `/images/pxeboot/initrd.img` in this version of this spec)
- The `--bootc-installer-payload-ref` argument to `image-builder` can optionally be used to copy a container image from the host's container storage to `/var/lib/containers/storage` in the squashfs archive.

## Example ISOs
This repository contains the following example ISOs:

- `bazzite` - Clone of the Bazzite Live ISO but built using this contract and `image-builder`. Contains a KDE environment with flatpaks, and an offline installer.
- `kinoite` - Live environment of Fedora Kinoite (Fedora with KDE)
- `bluefin-lts` - Live environment of Bluefin LTS (CentOS Stream 10 + GNOME)
- `debian` - Tiny Debian text environment, log in with `liveuser`
- `ubuntu` - Tiny Ubuntu text environment, log in with `liveuser`
- `fedora-payload` - Minimal text-based Fedora bootc online installer.

## Building ISOs
Build the container:

```
sudo just container <CONTAINER>
```

Then build the ISO:

```
sudo just iso <CONTAINER>
```

Since you need a fairly new version (TBD) of `image-builder`, I recommend using a containerized version of `image-builder` with all patches required for this spec ready:

```
sudo just build-image-builder iso-in-container <CONTAINER>
```

## Quirks
- Due to an issue in `image-builder`, `/etc/os-release` in the container must contain `VERSION_ID`. Its value is currently unused, though.
- The squashfs is currently not SELinux-labeled. This will be fixed and configurable in the next version of the spec.
- The spec should live in `osbuild/image-builder-cli`.
