#! /bin/sh

BASE_DIR=`pwd`/tmp
BOX_NAME="freebsd-zfs-build"
BOX_DIR="${BASE_DIR}/${BOX_NAME}"
EXPORT_NAME="freebsd-zfs"

mkdir -p "${BASE_DIR}"

VBoxManage createvm --name "${BOX_NAME}" --ostype FreeBSD_64 --basefolder "${BASE_DIR}"
VBoxManage registervm "${BOX_DIR}/${BOX_NAME}.vbox"

cp disk1.vmdk "${BOX_DIR}/${BOX_NAME}.vmdk"
VBoxManage internalcommands sethduuid "${BOX_DIR}/${BOX_NAME}.vmdk"

VBoxManage storagectl "${BOX_NAME}" --name LsiLogic --add scsi --controller LsiLogic
VBoxManage storageattach "${BOX_NAME}" --storagectl LsiLogic --port 0 --device 0 --type hdd --medium "${BOX_DIR}/${BOX_NAME}.vmdk"

VBoxManage modifyvm "${BOX_NAME}" --memory 4096

vagrant package --base "${BOX_NAME}" --output "${EXPORT_NAME}.box"

VBoxManage unregistervm "${BOX_NAME}" --delete
rmdir "${BASE_DIR}"
