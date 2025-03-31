# rc-warewulf-image-builds

## Research Computing - Warewulf Node Image Build System

This repo contains Makefiles and Containerfiles to build Warewulf-compatible node images (containers) for provisioning supercomputers.

> ⚠️ **ONLY RUN ON `warewulf.rc.asu.edu`**  
> Running elsewhere is untested and potentially destructive. Assumes specific repo layout and that Podman is used **only** for building containers.

---

## Features

- Builds container images for multiple architectures
- Handles driver downloads (NVIDIA, MLX)
- Syncs `/etc/passwd` and `/etc/group` from host to resolve sync-user issues
- Automates import to Warewulf via `wwctl image import`
- Creates dracut initframfs on import
- Supports variants for CUDA, ROCm, FPGA, ARM, etc.

---

## Usage

### Build All Images

```bash
make
```

### Build a Specific Variant

```bash
make <variant>
# Example:
make cuda
```

### Build Multi-Arch Images

QEMU is automatically set up for cross-arch builds. Manual setup (if needed):

```bash
sudo podman run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

More info in [Warewulf’s multi-arch docs](https://warewulf.org/docs/v4.6.x/images/images.html#image-architecture)

---

## Import to Warewulf

After building, run:

```bash
make install
```

Or manually run the commands printed at the end of the build.

---

## Adding a New Variant

1. Copy an existing `Containerfile.<variant>`
2. Modify as needed
3. Add a new block in the `Makefile` using the existing targets as a template

---

## `podman_build` Function

To define a new image build target, use the `podman_build` macro in the Makefile:

```make
$(call podman_build,<variant>,<tag>,<arch>,<os_version>,<repo_overlay>)
```

**Arguments:**

- `<variant>`: name of the variant (should match Containerfile suffix) (e.g., `cuda`, `rocm`)
- `<tag>`: full image tag (e.g., `sol-x86_64-rocky8.10-cuda-565.57.01`)
- `<arch>`: target architecture (e.g., `x86_64`, `aarch64`)
- `<os_version>`: OS version (e.g., `8.10`, `9.5`)
- `<repo_overlay>`: repo overlay directory (e.g., `repos-rocky8`, `repos-aarch64`)

Make sure to define variables like `TAG`, `TARGET_ARCH`, `OS_VERSION`, and `REPOS` in your target block before calling `podman_build`.

Example:

```make
cuda:
 $(eval TARGET_ARCH := x86_64)
 $(eval OS_VERSION := 8.10)
 $(eval REPOS := repos-rocky8)
 $(eval TAG := sol-$(TARGET_ARCH)-rocky$(OS_VERSION)-cuda-$(NVIDIA_VERSION))
 $(MAKE) init Containerfile.$@ $(call get-nvidia-driver,$(TARGET_ARCH))
 $(call podman_build,$@,$(TAG),$(TARGET_ARCH),$(OS_VERSION),$(REPOS))
 @$(MAKE) success
```

---

## Cleanup

### `make clean`

- Deletes temporary build files (`.buildtmp/`, `.install.tmp`)
- Deletes `.tar` images in the current directory
- Calculates and prints how much disk space was freed

Safe to run on most systems.

### `make veryclean`

- Runs everything in `make clean`
- Prunes dangling Podman images
- Stops and removes external Podman containers
- Deletes all Podman overlay storage
- Resets Podman system state (`podman system reset -f`)

**Destructive** — should only be run on `warewulf.rc.asu.edu`.

---

## Global Variables (from Makefile)

| Variable            | Description                      |
|---------------------|----------------------------------|
| `NVIDIA_VERSION`     | Default: `565.57.01`             |
| `MLX_VERSION`        | Default: `24.10-2.1.8.0`         |
| `WWDRACUT_VERSION`   | Default: `4.6.0`                 |
| `RSTUDIO_VERSION`    | Default: `2024.12.1-563`         |
