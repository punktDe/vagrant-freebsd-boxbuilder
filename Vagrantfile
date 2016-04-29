Vagrant.configure(2) do |config|

  # Which box to use for building
  $build_box = 'freebsd/FreeBSD-10.3-RELEASE'

  # Which FreeBSD version to install in target box
  $freebsd_version = '10.3'

  # ZFS target disk specification
  #
  # * Disk size and swap size in megabytes
  # * Controller must match config of build box from Hashicorp
  # * Device depends on build box, too
  $disk_file = 'disk1.vmdk'
  $disk_size = 20 * 1024
  $swap_size = 4096
  $disk_controller = 'IDE Controller'
  $disk_device = 'ada1'

  # how far to seek to the end of the device to erase GPT information
  $disk_seek = $disk_size * 2048 - 34

  # User settable  box parameters here
  $vagrant_mount_path = '/var/vagrant'
  $virtual_machine_ip = '10.20.30.193'
  $virtual_machine_hostname = "zfs.vagrant.dev.punkt.de"
  $virtual_box_machine_name = "FreeBSD-10.3-ZFS"

  # Use proper shell
  config.ssh.shell = 'sh'

  # Use NFS instead of folder sharing
  config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true
  config.vm.synced_folder ".", "#{$vagrant_mount_path}", :nfs => true, :nfs_version => 3

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = $build_box

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: $virtual_machine_ip

  # Customize VB settings
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = "2"

    unless File.exist?($disk_file)
      vb.customize ['createhd', '--format', 'VMDK', '--filename', $disk_file, '--variant', 'Standard', '--size', $disk_size]
    end
    vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 1, '--device', 0, '--type', 'hdd', '--medium', $disk_file]
  end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: <<-SHELL

    # fetch and update FreeBSD source code
    ln -sf ../../bin/svnlite /usr/local/bin/svn
    test -f /usr/src/UPDATING || svn co "svn://svn0.eu.freebsd.org/base/releng/#{$freebsd_version}" /usr/src
    echo "SVN_UPDATE=		yes" > /etc/make.conf
    cd /usr/src && make update
    cp /var/vagrant/files/VIMAGE /usr/src/sys/amd64/conf

    # check if source changed and we need to rebuild everything
    if [ ! -f /usr/obj/usr/src/bin/freebsd-version/freebsd-version -o /usr/src/UPDATING -nt /usr/obj/usr/src/bin/freebsd-version/freebsd-version ]
    then
      chflags -R noschg /usr/obj
      rm -rf /usr/obj
      cd /usr/src && make -j 2 KERNCONF=VIMAGE buildworld buildkernel
    fi

    # erase target disk
    dd if=/dev/zero of=/dev/#{$disk_device} count=34
    dd if=/dev/zero of=/dev/#{$disk_device} oseek=#{$disk_seek}

    # create partitions and install bootloader
    gpart create -s gpt #{$disk_device}
    gpart add -a 4k -s 512k -t freebsd-boot #{$disk_device}
    gpart add -a 1m -s #{$swap_size}m -t freebsd-swap -l swap0 #{$disk_device}
    gpart add -a 1m -t freebsd-zfs -l disk0 #{$disk_device}
    gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 #{$disk_device}

    # load ZFS
    kldload opensolaris
    kldload zfs
    sysctl vfs.zfs.min_auto_ashift=12

    # create and configure zpool
    zpool destroy -f zroot
    zpool create -f -o altroot=/mnt -o cachefile=/var/tmp/zpool.cache zroot /dev/gpt/disk0
    zpool set bootfs=zroot zroot
    zfs set checksum=fletcher4 zroot

    # install FreeBSD into ZFS
    cd /usr/src && make DESTDIR=/mnt/zroot KERNCONF=VIMAGE installworld installkernel distribution
    cp /var/vagrant/files/fstab /mnt/zroot/etc
    cp /var/vagrant/files/rc.conf /mnt/zroot/etc
    cp /var/vagrant/files/loader.conf /mnt/zroot/boot

    # install some necessary packages
    export ASSUME_ALWAYS_YES="yes"
    cp /etc/resolv.conf /mnt/zroot/etc
    chroot /mnt/zroot pkg update
    chroot /mnt/zroot pkg install ca_root_nss sudo bash virtualbox-ose-additions

    # create and configure vagrant user
    echo "%vagrant ALL=(ALL) NOPASSWD: ALL" > /mnt/zroot/usr/local/etc/sudoers.d/vagrant
    chmod 640 /mnt/zroot/usr/local/etc/sudoers.d/vagrant
    chroot /mnt/zroot sh -c 'echo "*" | pw useradd -n vagrant -s /usr/local/bin/bash -m -G wheel -H 0'
    mkdir /mnt/zroot/home/vagrant/.ssh
    chmod 700 /mnt/zroot/home/vagrant/.ssh
    touch /mnt/zroot/home/vagrant/.ssh/authorized_keys
    chroot /mnt/zroot chown -R vagrant:vagrant /home/vagrant
    chroot /mnt/zroot fetch -o /home/vagrant/.ssh/authorized_keys https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub

    # finish ZFS setup and unmount disk
    rm -f /mnt/zroot/etc/resolv.conf
    cp /var/tmp/zpool.cache /mnt/zroot/boot/zfs/zpool.cache
    zfs unmount -a
    zfs set mountpoint=legacy zroot
  SHELL
end
