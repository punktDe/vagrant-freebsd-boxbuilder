#! /bin/sh

BASE_DIR=`pwd`/tmp

VERSION=`grep ' $freebsd_version =' Vagrantfile | sed -e "s/^[^']*'//" -e "s/'$//" -e "s/\.//"`
BOX_BASENAME="freebsd-${VERSION}"

mkdir -p "${BASE_DIR}"

for fs in zfs ufs
do
  boxname="${BOX_BASENAME}-${fs}"
  boxdir="${BASE_DIR}/${boxname}"

  VBoxManage createvm --name "${boxname}" --ostype FreeBSD_64 --basefolder "${BASE_DIR}"
  VBoxManage registervm "${boxdir}/${boxname}.vbox"

  cp "${fs}.vmdk" "${boxdir}/${boxname}.vmdk"
  VBoxManage internalcommands sethduuid "${boxdir}/${boxname}.vmdk"

  VBoxManage storagectl "${boxname}" --name LsiLogic --add scsi --controller LsiLogic
  VBoxManage storageattach "${boxname}" --storagectl LsiLogic --port 0 --device 0 --type hdd --medium "${boxdir}/${boxname}.vmdk"

  VBoxManage modifyvm "${boxname}" --memory 4096
  VBoxManage modifyvm "${boxname}" --graphicscontroller vmsvga
  VBoxManage modifyvm "${boxname}" --vram 32

  rm -f "${boxname}.box"
  vagrant package --base "${boxname}" --output "${boxname}.box"

  VBoxManage unregistervm "${boxname}" --delete
done

rmdir "${BASE_DIR}"
