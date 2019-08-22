Vagrant.configure(2) do |config|

  # Which box to use for building
  $build_box = 'punktde/freebsd-120-ufs'

  # How many cores to use
  $build_cores = 4

  # Which FreeBSD version to install in target box
  $freebsd_version = '12.0'

  # minimal packages necessary to run Vagrant and Ansible
  $initial_package_list = 'sudo bash virtualbox-ose-additions-nox11 python3'

  # Target disk specification
  #
  # * Disk size and swap size in megabytes
  # * Controller must match config of build box from Hashicorp
  # * Device depends on build box, too
  $disk_controller = 'LsiLogic'

  $zfs_disk_size = 60 * 1024
  $zfs_swap_size = 4096
  $zfs_disk_device = 'da1'

  $ufs_disk_size = 60 * 1024
  $ufs_swap_size = 4096
  $ufs_disk_device = 'da2'

  # how far to seek to the end of the device to erase GPT information
  $zfs_disk_seek = $zfs_disk_size * 2048 - 34
  $ufs_disk_seek = $ufs_disk_size * 2048 - 34

  # User settable  box parameters here
  $vagrant_mount_path = '/var/vagrant'
  $virtual_machine_ip = '10.20.30.193'

  # Use NFS instead of folder sharing
  config.vm.synced_folder '.', '/vagrant', id: 'vagrant-root', disabled: true
  config.vm.synced_folder '.', "#{$vagrant_mount_path}", :nfs => true, :nfs_version => 3

  # Enable SSH keepalive to work around https://github.com/hashicorp/vagrant/issues/516
  config.ssh.keep_alive = true

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = $build_box

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network 'private_network', ip: $virtual_machine_ip

  # Customize build VB settings
  config.vm.provider 'virtualbox' do |vb|
    vb.memory = 4096
    vb.cpus = $build_cores

    if File.exist?('zfs.vmdk')
      vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 1, '--device', 0, '--type', 'hdd', '--medium', 'none']
      vb.customize ['closemedium', 'zfs.vmdk', '--delete']
    end
    if File.exist?('ufs.vmdk')
      vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 2, '--device', 0, '--type', 'hdd', '--medium', 'none']
      vb.customize ['closemedium', 'ufs.vmdk', '--delete']
    end
    vb.customize ['createhd', '--format', 'VMDK', '--filename', 'zfs.vmdk', '--variant', 'Standard', '--size', $zfs_disk_size]
    vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 1, '--device', 0, '--type', 'hdd', '--medium', 'zfs.vmdk']
    vb.customize ['createhd', '--format', 'VMDK', '--filename', 'ufs.vmdk', '--variant', 'Standard', '--size', $ufs_disk_size]
    vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 2, '--device', 0, '--type', 'hdd', '--medium', 'ufs.vmdk']
  end

  # Real work starts here
  config.vm.provision 'shell', inline: <<-SHELL

    # fetch and update FreeBSD source code
    ln -sf ../../bin/svnlite /usr/local/bin/svn
    test -f /usr/src/UPDATING || svn co "https://svn.freebsd.org/base/releng/#{$freebsd_version}" /usr/src
    echo 'SVN_UPDATE=		yes' > /etc/make.conf
    echo 'WITHOUT_DEBUG_FILES=	yes' > /etc/src.conf
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

    # create mountpoints
    mkdir /zfs
    mkdir /ufs

    # load ZFS
    kldload opensolaris
    kldload zfs
    sysctl vfs.zfs.min_auto_ashift=12

    # create and configure zpool
    #
    # create boot environment friendly layout
    # see https://wiki.freebsd.org/RootOnZFS/GPTZFSBoot
    zpool create -f -o cachefile=/var/tmp/zpool.cache -o altroot=/zfs zroot gpt/root
    zfs set compression=on zroot

    zfs create -o mountpoint=none                                  zroot/ROOT
    zfs create -o mountpoint=/ -o canmount=noauto                  zroot/ROOT/default

    mount -t zfs zroot/ROOT/default /zfs

    zfs create -o mountpoint=/tmp  -o exec=on      -o setuid=off   zroot/tmp
    zfs create -o mountpoint=/usr  -o canmount=off                 zroot/usr
    zfs create                     -o exec=off     -o setuid=off   zroot/usr/src
    zfs create                                                     zroot/usr/obj
    zfs create                                     -o setuid=off   zroot/usr/ports
    zfs create                     -o exec=off     -o setuid=off   zroot/usr/ports/distfiles
    zfs create                     -o exec=off     -o setuid=off   zroot/usr/ports/packages
    zfs create -o mountpoint=/var  -o canmount=off                 zroot/var
    zfs create                     -o exec=off     -o setuid=off   zroot/var/audit
    zfs create                     -o exec=off     -o setuid=off   zroot/var/crash
    zfs create                     -o exec=off     -o setuid=off   zroot/var/log
    zfs create -o atime=on         -o exec=off     -o setuid=off   zroot/var/mail
    zfs create                     -o exec=on      -o setuid=off   zroot/var/tmp
    zfs create -o mountpoint=/home                                 zroot/home

    chmod 1777 /zfs/var/tmp
    chmod 1777 /zfs/tmp

    zpool set bootfs=zroot/ROOT/default zroot

    # create and mount UFS filesystem
    newfs /dev/#{$ufs_disk_device}p3
    mount /dev/#{$ufs_disk_device}p3 /ufs

    for dstdir in /zfs /ufs
    do
      # install FreeBSD
      cd /usr/src && make "DESTDIR=${dstdir}" KERNCONF=VIMAGE installworld installkernel distribution

      # install packages
      export ASSUME_ALWAYS_YES="yes"
      pkg -r "${dstdir}" install pkg ca_root_nss
      pkg -r "${dstdir}" install #{$initial_package_list}

      # create and configure vagrant user
      echo "#includedir /usr/local/etc/sudoers.d" > "${dstdir}/usr/local/etc/sudoers"
      chmod 440 "${dstdir}/usr/local/etc/sudoers"
      echo "%vagrant ALL=(ALL) NOPASSWD: ALL" > "${dstdir}/usr/local/etc/sudoers.d/vagrant"
      chmod 440 "${dstdir}/usr/local/etc/sudoers.d/vagrant"
      pw -R "${dstdir}" groupadd -n vagrant -g 1001
      echo "*" | pw -R "${dstdir}" useradd -n vagrant -u 1001 -s /usr/local/bin/bash -m -g 1001 -G wheel -H 0
      mkdir "${dstdir}/home/vagrant/.ssh"
      chmod 700 "${dstdir}/home/vagrant/.ssh"
      cp /var/vagrant/files/vagrant.pub "${dstdir}/home/vagrant/.ssh/authorized_keys"
      chown -R 1001:1001 "${dstdir}/home/vagrant"

      # copy config files
      cp "/var/vagrant/files${dstdir}/fstab" "${dstdir}/etc"
      cp "/var/vagrant/files${dstdir}/rc.conf" "${dstdir}/etc"
      cp "/var/vagrant/files${dstdir}/loader.conf" "${dstdir}/boot"
    done

    # finish ZFS setup and unmount disk
    mkdir -p /zfs/boot/zfs
    cp /var/tmp/zpool.cache /zfs/boot/zfs/zpool.cache
    zfs umount -a

    # unmount UFS disk
    umount /ufs
  SHELL
end
