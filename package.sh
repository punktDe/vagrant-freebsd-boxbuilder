#! /bin/sh

BASE_DIR=$(pwd)/tmp

VERSION=$(grep ' $freebsd_version =' Vagrantfile | sed -e "s/^[^']*'//" -e "s/'$//" -e "s/\.//")
BOX_BASENAME="freebsd-${VERSION}"

mkdir -p "${BASE_DIR}"

# Save stdout for progress messages
exec 3>&1

# Direct command output to central logfile
datetime=$(date +%Y%m%d%H%M)
exec 1>"package-${datetime}.log" 2>&1

# Print start message
echo "============================================================" >&3
echo "Packaging boxes for FreeBSD ${VERSION}."                      >&3
echo "Logging to package-${datetime}.log."                          >&3
echo "============================================================" >&3

for fs in zfs ufs
do
  boxname="${BOX_BASENAME}-${fs}"
  boxdir="${BASE_DIR}/${boxname}"

  echo "------------------------------------------------------------" >&3
  echo "Creating box ${boxname} ... "                                 >&3

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
  echo "done."                                                        >&3
  echo "------------------------------------------------------------" >&3
done

rmdir "${BASE_DIR}"

# Print final message and exit
echo "============================================================" >&3
echo "Packaging finished. Use these steps to test the results:"     >&3
echo "cd test"                                                      >&3
echo "./test.sh"                                                    >&3
echo "============================================================" >&3
