Vagrant.configure(2) do |config|

  # Which box to use for building
  $build_box = 'freebsd/FreeBSD-10.3-RELEASE'

  # How many cores to use
  $build_cores = 4

  # Which FreeBSD version to install in target box
  $freebsd_version = '10.3'

  # Wich pkg repo to use
  $package_version = '102-2016Q3'
  $package_set = 'ap22-php56'

  # Target disk specification
  #
  # * Disk size and swap size in megabytes
  # * Controller must match config of build box from Hashicorp
  # * Device depends on build box, too
  $disk_controller = 'IDE Controller'

  $zfs_disk_size = 20 * 1024
  $zfs_swap_size = 4096
  $zfs_disk_device = 'ada1'

  $ufs_disk_size = 20 * 1024
  $ufs_swap_size = 4096
  $ufs_disk_device = 'ada2'

  # how far to seek to the end of the device to erase GPT information
  $zfs_disk_seek = $zfs_disk_size * 2048 - 34
  $ufs_disk_seek = $ufs_disk_size * 2048 - 34

  # User settable  box parameters here
  $vagrant_mount_path = '/var/vagrant'
  $virtual_machine_ip = '10.20.30.193'

  # Use proper shell
  config.ssh.shell = 'sh'

  # Use NFS instead of folder sharing
  config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true
  config.vm.synced_folder ".", "#{$vagrant_mount_path}", :nfs => true, :nfs_version => 3

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = $build_box

  # Increase the boot timeout for first start of the build box.
  # Hashicorp run freebsd-update on start which may take a long time.
  config.vm.boot_timeout = 600

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: $virtual_machine_ip

  # Customize build VB settings
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = $build_cores

    if File.exist?('zfs.vmdk')
      vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 1, '--device', 0, '--type', 'hdd', '--medium', 'none']
      vb.customize ['closemedium', 'zfs.vmdk', '--delete']
    end
    if File.exist?('ufs.vmdk')
      vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 1, '--device', 1, '--type', 'hdd', '--medium', 'none']
      vb.customize ['closemedium', 'ufs.vmdk', '--delete']
    end
    vb.customize ['createhd', '--format', 'VMDK', '--filename', 'zfs.vmdk', '--variant', 'Standard', '--size', $zfs_disk_size]
    vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 1, '--device', 0, '--type', 'hdd', '--medium', 'zfs.vmdk']
    vb.customize ['createhd', '--format', 'VMDK', '--filename', 'ufs.vmdk', '--variant', 'Standard', '--size', $ufs_disk_size]
    vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 1, '--device', 1, '--type', 'hdd', '--medium', 'ufs.vmdk']
  end

  # Real work starts here
  config.vm.provision "shell", inline: <<-SHELL

    # fetch and update FreeBSD source code
    ln -sf ../../bin/svnlite /usr/local/bin/svn
    test -f /usr/src/UPDATING || svn co "svn://svn0.eu.freebsd.org/base/releng/#{$freebsd_version}" /usr/src
    echo "SVN_UPDATE=		yes" > /etc/make.conf
    cd /usr/src && make update
    cp /var/vagrant/files/VIMAGE /usr/src/sys/amd64/conf

    # check if source changed and rebuild everything if necessary
    if [ ! -f /usr/obj/usr/src/bin/freebsd-version/freebsd-version -o /usr/src/UPDATING -nt /usr/obj/usr/src/bin/freebsd-version/freebsd-version ]
    then
      chflags -R noschg /usr/obj
      rm -rf /usr/obj
      cd /usr/src && make -j #{$build_cores} KERNCONF=VIMAGE buildworld buildkernel
    fi

    # erase target disks
    dd if=/dev/zero of=/dev/#{$zfs_disk_device} count=34
    dd if=/dev/zero of=/dev/#{$zfs_disk_device} oseek=#{$zfs_disk_seek}
    dd if=/dev/zero of=/dev/#{$ufs_disk_device} count=34
    dd if=/dev/zero of=/dev/#{$ufs_disk_device} oseek=#{$ufs_disk_seek}

    # create partitions and install bootloader for ZFS disk
    gpart create -s gpt #{$zfs_disk_device}
    gpart add -a 512k -s 512k -t freebsd-boot -l boot #{$zfs_disk_device}
    gpart add -a 1m -s #{$zfs_swap_size}m -t freebsd-swap -l swap #{$zfs_disk_device}
    gpart add -a 1m -t freebsd-zfs -l root #{$zfs_disk_device}
    gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 #{$zfs_disk_device}

    # create partitions and install bootloader for UFS disk
    gpart create -s gpt #{$ufs_disk_device}
    gpart add -a 512k -s 512k -t freebsd-boot #{$ufs_disk_device}
    gpart add -a 1m -s #{$ufs_swap_size}m -t freebsd-swap #{$ufs_disk_device}
    gpart add -a 1m -t freebsd-ufs #{$ufs_disk_device}
    gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 #{$ufs_disk_device}

    # load ZFS
    kldload opensolaris
    kldload zfs
    sysctl vfs.zfs.min_auto_ashift=12

    # create and configure zpool
    zpool create -f -o cachefile=/var/tmp/zpool.cache zroot gpt/root
    zpool set bootfs=zroot zroot
    zfs set checksum=fletcher4 zroot
    zfs set compression=lz4 zroot

    # create and mount UFS filesystem
    newfs /dev/#{$ufs_disk_device}p3
    mount /dev/#{$ufs_disk_device}p3 /mnt

    export ASSUME_ALWAYS_YES="yes"

    for dstdir in /zroot /mnt
    do
      # install FreeBSD
      cd /usr/src && make "DESTDIR=${dstdir}" KERNCONF=VIMAGE installworld installkernel distribution

      # install some necessary packages
      cp /etc/resolv.conf "${dstdir}/etc"
      echo "FreeBSD: { enabled: no }" > "${dstdir}/usr/local/etc/pkg/repos/FreeBSD.conf"
      echo "#{$package_set}: { url: https://packages.pluspunkthosting.de/packages/#{$package_version}-#{$package_set}, enabled: yes, mirror_type: NONE }" > "${dstdir}/usr/local/etc/pkg/repos/#{$package_set}.conf"
      echo "common: { url: https://packages.pluspunkthosting.de/packages/#{$package_version}-common, enabled: no, mirror_type: NONE }" > "/usr/local/etc/pkg/repos/common.conf"
      chroot "${dstdir}" pkg update
      chroot "${dstdir}" pkg install ca_root_nss sudo bash virtualbox-ose-additions

      # create and configure vagrant user
      echo "%vagrant ALL=(ALL) NOPASSWD: ALL" > "${dstdir}/usr/local/etc/sudoers.d/vagrant"
      chmod 640 "${dstdir}/usr/local/etc/sudoers.d/vagrant"
      chroot "${dstdir}" sh -c 'echo "*" | pw useradd -n vagrant -s /usr/local/bin/bash -m -G wheel -H 0'
      mkdir "${dstdir}/home/vagrant/.ssh"
      chmod 700 "${dstdir}/home/vagrant/.ssh"
      touch "${dstdir}/home/vagrant/.ssh/authorized_keys"
      chroot "${dstdir}" chown -R vagrant:vagrant /home/vagrant
      chroot "${dstdir}" fetch -o /home/vagrant/.ssh/authorized_keys https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub

      # clean up
      rm -f "${dstdir}/etc/resolv.conf"
    done

    # copy config files for ZFS box
    cp /var/vagrant/files/zfs/fstab /zroot/etc
    cp /var/vagrant/files/zfs/rc.conf /zroot/etc
    cp /var/vagrant/files/zfs/loader.conf /zroot/boot

    # finish ZFS setup and unmount disk
    mkdir -p /zroot/boot/zfs
    cp /var/tmp/zpool.cache /zroot/boot/zfs/zpool.cache
    zfs umount -a
    zfs set mountpoint=legacy zroot

    # copy config files for UFS box
    cp /var/vagrant/files/ufs/fstab /mnt/etc
    cp /var/vagrant/files/ufs/rc.conf /mnt/etc
    cp /var/vagrant/files/ufs/loader.conf /mnt/boot

    # unmount UFS disk
    umount /mnt
  SHELL
end
