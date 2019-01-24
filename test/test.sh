#! /bin/sh

VERSION=`grep ' $freebsd_version =' ../Vagrantfile | sed -e "s/^[^']*'//" -e "s/'$//" -e "s/\.//"`

vagrant box remove -f punktde/zfs-test || true
vagrant box remove -f punktde/ufs-test || true
vagrant destroy -f || true

vagrant box add --name punktde/zfs-test "../freebsd-${VERSION}-zfs.box"
vagrant box add --name punktde/ufs-test "../freebsd-${VERSION}-ufs.box"

for fs in zfs ufs
do
	ln -sf Vagrantfile.${fs} Vagrantfile
	vagrant up
	echo ""
	echo "***** SSH'ing into the ${fs} box - once you leave it again, it will be destroyed. *****"
	echo ""
	vagrant ssh
	vagrant halt
	vagrant destroy -f
done

vagrant box remove -f punktde/zfs-test
vagrant box remove -f punktde/ufs-test
