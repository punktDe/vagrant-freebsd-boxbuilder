Vagrant.configure(2) do |config|

  # Which box to use for building
  $build_box = 'punktde/freebsd-131-ufs'

  # How many cores to use
  $build_cores = 4

  # Which FreeBSD version to install in target box
  $freebsd_version = '13.1'

  # Minimal packages necessary to run Vagrant and Ansible
  $initial_package_list = 'sudo bash virtualbox-ose-additions-nox11 python3'

  # Target disk and controller specification
  #
  # * Disk size and swap size in megabytes
  # * Controller must match config of the build box used
  # * Host I/O cache - 'on' or 'off' - the former seems to be necessary when
  #   running Vagrant on FreeBSD with ZFS
  $disk_controller = 'LsiLogic'
  $disk_controller_hostcache = 'on'

  $zfs_disk_size = 60 * 1024
  $zfs_swap_size = 4096
  $zfs_disk_device = 'da1'

  $ufs_disk_size = 60 * 1024
  $ufs_swap_size = 4096
  $ufs_disk_device = 'da2'

  # How far to seek to the end of the device to erase GPT information
  $zfs_disk_seek = $zfs_disk_size * 2048 - 34
  $ufs_disk_seek = $ufs_disk_size * 2048 - 34

  # Enable SSH keepalive to work around https://github.com/hashicorp/vagrant/issues/516
  config.ssh.keep_alive = true

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = $build_box
  
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
    vb.customize ['storagectl', :id, '--name', 'LsiLogic', '--hostiocache', $disk_controller_hostcache ]
    vb.customize ['createhd', '--format', 'VMDK', '--filename', 'zfs.vmdk', '--variant', 'Standard', '--size', $zfs_disk_size]
    vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 1, '--device', 0, '--type', 'hdd', '--medium', 'zfs.vmdk']
    vb.customize ['createhd', '--format', 'VMDK', '--filename', 'ufs.vmdk', '--variant', 'Standard', '--size', $ufs_disk_size]
    vb.customize ['storageattach', :id,  '--storagectl', $disk_controller, '--port', 2, '--device', 0, '--type', 'hdd', '--medium', 'ufs.vmdk']
  end

  # Real work starts here
  config.vm.provision 'shell', inline: <<-SHELL

    # Save stdout for progress messages
    exec 3>&1

    # Direct command output to central logfile
    datetime=$(date +%Y%m%d%H%M)
    exec 1>"/vagrant/build-${datetime}.log" 2>&1

    # Print start message
    echo "============================================================" >&3
    echo "Starting build for FreeBSD #{$freebsd_version}."              >&3
    echo "Logging to build-${datetime}.log."                            >&3
    echo "============================================================" >&3

    # Install git
    echo "------------------------------------------------------------" >&3
    echo "Installing git ... "                                          >&3
    pkg install -y pkg
    pkg install -y ca_root_nss git-tiny
    echo "done."                                                        >&3
    echo "------------------------------------------------------------" >&3

    # Don't build debug and test code
    echo 'WITHOUT_DEBUG_FILES=	yes' > /etc/src.conf
    echo 'WITHOUT_TESTS=	yes' >> /etc/src.conf

    # Fetch and update FreeBSD source code
    echo "------------------------------------------------------------" >&3
    if [ ! -f /usr/src/UPDATING ]
    then
      echo "Cloning FreeBSD #{$freebsd_version} source tree ... "       >&3
      git clone -b releng/#{$freebsd_version} --depth 1 https://git.freebsd.org/src.git /usr/src
    else
      echo "Updating FreeBSD #{$freebsd_version} source tree ... "      >&3
      cd /usr/src && git pull
    fi
    echo "done."                                                        >&3
    echo "------------------------------------------------------------" >&3

    # Check if source code changed and rebuild everything if necessary
    if [ ! -f /usr/obj/usr/src/bin/freebsd-version/freebsd-version -o /usr/src/UPDATING -nt /usr/obj/usr/src/bin/freebsd-version/freebsd-version ]
    then
      echo "------------------------------------------------------------" >&3
      echo "Building FreeBSD #{$freebsd_version} ... "                    >&3
      chflags -R noschg /usr/obj
      rm -rf /usr/obj
      cd /usr/src && make -j #{$build_cores} buildworld buildkernel
      echo "done."                                                        >&3
      echo "------------------------------------------------------------" >&3
    fi

    # Create and mount all target partitions and filesystems
    echo "------------------------------------------------------------" >&3
    echo "Setting up target disks ... "                                 >&3

    # Erase target disks
    dd if=/dev/zero of=/dev/#{$zfs_disk_device} count=34
    dd if=/dev/zero of=/dev/#{$zfs_disk_device} oseek=#{$zfs_disk_seek}
    dd if=/dev/zero of=/dev/#{$ufs_disk_device} count=34
    dd if=/dev/zero of=/dev/#{$ufs_disk_device} oseek=#{$ufs_disk_seek}

    # Create partitions and install bootloader for ZFS disk
    gpart create -s gpt #{$zfs_disk_device}
    gpart add -a 512k -s 512k -t freebsd-boot -l boot #{$zfs_disk_device}
    gpart add -a 1m -s #{$zfs_swap_size}m -t freebsd-swap -l swap #{$zfs_disk_device}
    gpart add -a 1m -t freebsd-zfs -l root #{$zfs_disk_device}
    gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 #{$zfs_disk_device}

    # Create partitions and install bootloader for UFS disk
    gpart create -s gpt #{$ufs_disk_device}
    gpart add -a 512k -s 512k -t freebsd-boot #{$ufs_disk_device}
    gpart add -a 1m -s #{$ufs_swap_size}m -t freebsd-swap #{$ufs_disk_device}
    gpart add -a 1m -t freebsd-ufs #{$ufs_disk_device}
    gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 #{$ufs_disk_device}

    # Create mountpoints
    mkdir /zfs
    mkdir /ufs

    # Load ZFS
    kldload opensolaris
    kldload zfs
    sysctl vfs.zfs.min_auto_ashift=12

    # Create and configure zpool
    #
    # Create boot environment friendly layout,
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
    zfs create -o mountpoint=/home                                 zroot/usr/home

    chmod 1777 /zfs/var/tmp
    chmod 1777 /zfs/tmp

    zpool set bootfs=zroot/ROOT/default zroot

    # Create and mount UFS filesystem
    newfs /dev/#{$ufs_disk_device}p3
    mount /dev/#{$ufs_disk_device}p3 /ufs
    echo "done."                                                        >&3
    echo "------------------------------------------------------------" >&3

    for dstdir in /zfs /ufs
    do
      # Install FreeBSD
      echo "------------------------------------------------------------" >&3
      echo "Installing FreeBSD #{$freebsd_version} into ${dstdir} ... "   >&3
      cd /usr/src && make "DESTDIR=${dstdir}" installworld installkernel distribution
      echo "done."                                                        >&3
      echo "------------------------------------------------------------" >&3
  
      # Install packages
      echo "------------------------------------------------------------" >&3
      echo "Installing packages into ${dstdir} ... "                      >&3
      export ASSUME_ALWAYS_YES="yes"
      pkg -r "${dstdir}" install pkg ca_root_nss
      pkg -r "${dstdir}" install #{$initial_package_list}
      echo "done."                                                        >&3
      echo "------------------------------------------------------------" >&3
  
      # Create and configure vagrant user
      echo "------------------------------------------------------------" >&3
      echo "Creating vagrant user in ${dstdir} ... "                      >&3
      echo "#includedir /usr/local/etc/sudoers.d" > "${dstdir}/usr/local/etc/sudoers"
      chmod 440 "${dstdir}/usr/local/etc/sudoers"
      echo "%vagrant ALL=(ALL) NOPASSWD: ALL" > "${dstdir}/usr/local/etc/sudoers.d/vagrant"
      chmod 440 "${dstdir}/usr/local/etc/sudoers.d/vagrant"
      pw -R "${dstdir}" groupadd -n vagrant -g 1001
      echo "*" | pw -R "${dstdir}" useradd -n vagrant -u 1001 -s /usr/local/bin/bash -m -g 1001 -G wheel -H 0
      mkdir "${dstdir}/home/vagrant/.ssh"
      chmod 700 "${dstdir}/home/vagrant/.ssh"
      cp /vagrant/files/vagrant.pub "${dstdir}/home/vagrant/.ssh/authorized_keys"
      chown -R 1001:1001 "${dstdir}/home/vagrant"
      echo "done."                                                        >&3
      echo "------------------------------------------------------------" >&3

      # Copy config files
      echo "------------------------------------------------------------" >&3
      echo "Performing final configuration in ${dstdir} ... "             >&3
      cp "/vagrant/files${dstdir}/fstab" "${dstdir}/etc"
      cp "/vagrant/files${dstdir}/rc.conf" "${dstdir}/etc"
      cp "/vagrant/files${dstdir}/loader.conf" "${dstdir}/boot"
      echo "done."                                                        >&3
      echo "------------------------------------------------------------" >&3
    done

    # Finish ZFS setup and unmount all disks
    echo "------------------------------------------------------------" >&3
    echo "Cleaning up ... "                                             >&3
    mkdir -p /zfs/boot/zfs
    cp /var/tmp/zpool.cache /zfs/boot/zfs/zpool.cache
    zfs umount -a
    umount /ufs
    echo "done."                                                        >&3
    echo "------------------------------------------------------------" >&3

    # Print final message and exit
    echo "============================================================" >&3
    echo "Build and install finished. Use these steps to create box:"   >&3
    echo "vagrant halt"                                                 >&3
    echo "./package.sh"                                                 >&3
    echo "============================================================" >&3
  SHELL
end
