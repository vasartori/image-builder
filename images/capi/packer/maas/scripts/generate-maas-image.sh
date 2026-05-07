#!/bin/bash

QEMU_IMAGE_FILE=$1
IMAGE_NAME=$(basename $QEMU_IMAGE_FILE)
BASE_PATH=$(dirname $QEMU_IMAGE_FILE)
FIRMWARE=${FIRMWARE:-OVMF.fd}

echo "Qemu qcow2 file: $QEMU_IMAGE_FILE"
echo "Image name: $IMAGE_NAME"
echo "Firmware Type: $FIRMWARE"

if [[ $FIRMWARE == "bios" ]]; then
    PARTITION="/dev/nbd4p1"
else
    PARTITION="/dev/nbd4p2"
fi

TMP_DIR=$(mktemp -d /tmp/packer-maas-XXXX)
echo 'Binding packer qcow2 image output to nbd ...'
modprobe nbd
qemu-nbd -d /dev/nbd4
qemu-nbd -c /dev/nbd4 -n $QEMU_IMAGE_FILE
echo 'Waiting for partitions to be created...'
tries=0

while [ ! -e $PARTITION -a $tries -lt 60 ]; do
    sleep 1
    let tries++
done

if [[ $tries -gt 60 ]]; then
    echo "partition $PARTITION cannot be mounted. Stopping here!!"
    exit 2
fi

echo "mounting image..."
mount $PARTITION $TMP_DIR

if [[ $FIRMWARE != "bios" ]]; then
    mount "/dev/nbd4p1" "$TMP_DIR/boot/efi"
fi

echo 'Tarring up image...'
tar -Sczpf $BASE_PATH/$IMAGE_NAME.tar.gz --acls --selinux --xattrs -C $TMP_DIR  .
echo 'Unmounting image...'

if [[ $FIRMWARE != "bios" ]]; then
    umount "$TMP_DIR/boot/efi"
fi 

umount $TMP_DIR
qemu-nbd -d /dev/nbd4
rmdir $TMP_DIR
