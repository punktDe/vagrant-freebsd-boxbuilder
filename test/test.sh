#! /bin/sh

vagrant box remove -f punktde/zfs-test || true
vagrant box remove -f punktde/ufs-test || true
vagrant destroy -f || true

vagrant box add --name punktde/zfs-test ../punktde-freebsd-zfs.box
vagrant box add --name punktde/ufs-test ../punktde-freebsd-ufs.box

for fs in ZFS UFS
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
