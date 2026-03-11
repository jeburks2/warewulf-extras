#!/bin/bash
# Blame: Josh Burks <jeburks2@asu.edu> 2026-02-24
#
# run-wwinit.d zfs handler (pre-switchroot)
# Expects NEWROOT to be set (e.g. /newroot). Runs inside initramfs/dracut.

PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
NEWROOT="${NEWROOT:-/newroot}"

POOL_NAME="wwpool"
ROOT_DS="wwroot"

HF_DS="hf_cache"
HF_MOUNT_POINT="/mnt/hf_cache"

K3S_DS="k3s"
K3S_MOUNT_POINT="/var/lib/rancher/k3s"

RANCHER_DS="rancher"
RANCHER_MOUNT_POINT="/etc/rancher/node"

CONTAINER_DS="containerd"
CONTAINERD_MOUNT_POINT="/var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.zfs"


info(){ echo "info: $*"; }
die(){ echo "fatal: $*" >&2; exit 1; }

modprobe zfs || die "modprobe zfs failed"
modprobe nvme || die "modprobe nvme failed"


# Dynamically find first two 1TiB NVME disks
find_1tib_nvme_disks() {
  local found_disks=()
  local found_euids=()

  udevadm settle
  sleep 1
  
  for nvme_dev in /dev/nvme*n1; do
    if [ -e "$nvme_dev" ]; then
      # Get size in GB
      size_gb=$(lsblk -b -n -d -o SIZE "$nvme_dev" 2>/dev/null | awk '{print int($1/1024/1024/1024)}')
      
      # Check if it's approximately 1TiB (500-1200GB range to account for different manufacturers)
      if [ "$size_gb" -gt 500 ] && [ "$size_gb" -lt 1200 ]; then
        # Try to get EUID from device
        local device_name=$(basename "$nvme_dev")
        local euid=$(lsblk -b -n -d -o WWN "$nvme_dev")
        local euid_path="/dev/disk/by-id/nvme-$euid"
        if [ -e "$euid_path" ]; then
          echo "Found 1TiB NVME disk: $nvme_dev (${size_gb}GB) with EUID: $euid_path"
          found_disks+=("$nvme_dev")
          found_euids+=("$euid_path")
          if [ ${#found_disks[@]} -eq 2 ]; then
            break
          fi
        fi
      fi
    fi
  done
  
  if [ ${#found_disks[@]} -lt 2 ]; then
    die "Could not find two 1TiB NVME disks. Found: ${found_disks[*]}"
  fi
  
  DEV0="${found_euids[0]}"
  DEV1="${found_euids[1]}"
  echo "Selected devices: DEV0=$DEV0, DEV1=$DEV1"
}

set_rootfs_props() {
  zfs set quota=64G "${POOL_NAME}/${ROOT_DS}"
  zfs set compression=lz4 "${POOL_NAME}/${ROOT_DS}"
  zfs set atime=off "${POOL_NAME}/${ROOT_DS}"
  zfs set acltype=posix "${POOL_NAME}/${ROOT_DS}"
  zfs set xattr=sa "${POOL_NAME}/${ROOT_DS}"
}

set_hf_cache_props() {
  zfs set compression=lz4 "${POOL_NAME}/${HF_DS}"
  zfs set atime=off "${POOL_NAME}/${HF_DS}"
  zfs set acltype=off "${POOL_NAME}/${HF_DS}"
  zfs set xattr=off "${POOL_NAME}/${HF_DS}"
}

set_containerd_props() {
  zfs set compression=lz4 "${POOL_NAME}/${CONTAINER_DS}"
  zfs set atime=off "${POOL_NAME}/${CONTAINER_DS}"
  zfs set acltype=posix "${POOL_NAME}/${CONTAINER_DS}"
  zfs set xattr=sa "${POOL_NAME}/${CONTAINER_DS}"
}

set_k3s_props() {
  zfs set compression=lz4 "${POOL_NAME}/${K3S_DS}"
  zfs set atime=off "${POOL_NAME}/${K3S_DS}"
  zfs set acltype=posix "${POOL_NAME}/${K3S_DS}"
  zfs set xattr=sa "${POOL_NAME}/${K3S_DS}"
}

set_rancher_props() {
  zfs set compression=lz4 "${POOL_NAME}/${RANCHER_DS}"
  zfs set atime=off "${POOL_NAME}/${RANCHER_DS}"
  zfs set acltype=posix "${POOL_NAME}/${RANCHER_DS}"
  zfs set xattr=sa "${POOL_NAME}/${RANCHER_DS}"
}

# Create new ZFS pool with datasets
create_zfs_pool() {
  # Find and set the devices
  find_1tib_nvme_disks
  
  # Verify devices exist
  for d in "$DEV1" "$DEV0"; do
    [ -b "$d" ] || die "device $d missing"
  done
  
  info "creating zpool ${POOL_NAME} on ${DEV1} ${DEV0}"
  zpool create -f -m none "${POOL_NAME}" "${DEV1}" "${DEV0}" || die "Failed to create zpool ${POOL_NAME}"
  echo "${POOL_NAME}"
}

# Execeution starts here

# try to import all pools but do not mount
zpool import -a -N  >/dev/null 2>&1 

# look for our pool by name
FOUND_POOL="$(zpool list -H "$POOL_NAME" 2>/dev/null | awk '{print $1; exit}')"

if [ -z "$FOUND_POOL" ]; then
  # create pool if it does not exist
  create_zfs_pool
elif [ "$FOUND_POOL" != "$POOL_NAME" ]; then
  die "Found unexpected pool ${FOUND_POOL} when looking for ${POOL_NAME}"
else
  info "using existing pool ${POOL_NAME}"
fi

# If root dataset exists, remove it (stateless rootfs will be recreated on each boot)
if zfs list -H "${POOL_NAME}/${ROOT_DS}" >/dev/null 2>&1; then
  info "recreating ${POOL_NAME}/${ROOT_DS}"
  zfs unmount -f "${POOL_NAME}/${ROOT_DS}" >/dev/null 2>&1 
  zfs destroy -r -f "${POOL_NAME}/${ROOT_DS}" >/dev/null 2>&1 
fi

# create root dataset
if ! zfs list -H "${POOL_NAME}/${ROOT_DS}" >/dev/null 2>&1; then
  zfs create -o mountpoint=legacy "${POOL_NAME}/${ROOT_DS}" || die "Failed to create ${POOL_NAME}/${ROOT_DS}"
fi

# verify hf_cache dataset exists
if ! zfs list -H "${POOL_NAME}/${HF_DS}" >/dev/null 2>&1; then
  zfs create -u -o mountpoint="${HF_MOUNT_POINT}" "${POOL_NAME}/${HF_DS}"
fi

# verify k3s dataset exists
if ! zfs list -H "${POOL_NAME}/${K3S_DS}" >/dev/null 2>&1; then
  zfs create -u -o mountpoint="${K3S_MOUNT_POINT}" "${POOL_NAME}/${K3S_DS}"
fi

# verify containerd dataset exists
if ! zfs list -H "${POOL_NAME}/${CONTAINER_DS}" >/dev/null 2>&1; then
  zfs create -u -o mountpoint="${CONTAINERD_MOUNT_POINT}" "${POOL_NAME}/${CONTAINER_DS}"
fi

# verify rancher dataset exists
if ! zfs list -H "${POOL_NAME}/${RANCHER_DS}" >/dev/null 2>&1; then
  zfs create -u -o mountpoint="${RANCHER_MOUNT_POINT}" "${POOL_NAME}/${RANCHER_DS}"
fi

# Always reset properties to ensure correct settings, even if pool was pre-existing
set_rootfs_props
set_hf_cache_props
set_containerd_props
set_k3s_props
set_rancher_props
# ensure mountpoints exist under NEWROOT
mkdir -p "${NEWROOT}"

# mount new rootfs dataset into NEWROOT namespace
info "mounting ${POOL_NAME}/${ROOT_DS} at ${NEWROOT}"
mount -t zfs "${POOL_NAME}/${ROOT_DS}" "${NEWROOT}"

info "zfs setup complete"
exit 0

