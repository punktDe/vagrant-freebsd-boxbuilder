Vagrant.configure(2) do |config|

  # Which box to use for building
  $build_box = 'punktde/freebsd-140-ufs'

  # How many cores and memory (in GB) to use
  $build_cores = 4
  $build_memory = 4

  # Which FreeBSD version to install in target box
  $freebsd_version = '14.0'

  # Are we doing a major version upgrade?
  $freebsd_version_upgrade = 'no'

  # Minimal packages necessary to run Vagrant and Ansible
  $initial_package_list = 'sudo bash virtualbox-ose-additions-nox11 python3'

  # Base URL/mirror from which to retrieve the release tar archives
  $mirror_url = 'http://ftp.freebsd.org/pub/FreeBSD/releases/amd64'

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

  # Mount path for local project directory
  $vagrant_mount_path = '/var/vagrant'

  # IP address of the VM
  $virtual_machine_ip = '192.168.57.57'
  
  # Use NFS instead of folder sharing
  config.vm.synced_folder '.', '/vagrant', id: 'vagrant-root', disabled: true
  config.vm.synced_folder '.', "#{$vagrant_mount_path}", :nfs => true, :nfs_version => 3

  # Customize build VB settings
  config.vm.box = $build_box

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network 'private_network', ip: $virtual_machine_ip

  config.vm.provider 'virtualbox' do |vb|
    vb.memory = $build_memory * 1024
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
    exec 1>"/var/vagrant/build-${datetime}.log" 2>&1

    # Print start message
    echo "============================================================" >&3
    echo "Starting build for FreeBSD #{$freebsd_version}."              >&3
    echo "Logging to build-${datetime}.log."                            >&3
    echo "============================================================" >&3

    # Fetch FreeBSD release tarballs
    echo "------------------------------------------------------------" >&3
    echo "Fetching FreeBSD #{$freebsd_version} release tarballs ..."    >&3
    cd /var/tmp
    fetch "#{$mirror_url}/#{$freebsd_version}-RELEASE/base.txz"
    fetch "#{$mirror_url}/#{$freebsd_version}-RELEASE/kernel.txz"
    echo "done."                                                        >&3
    echo "------------------------------------------------------------" >&3

    # Create and mount all target partitions and filesystems
    echo "------------------------------------------------------------" >&3
    echo "Setting up target disks ... "                                 >&3

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
      cd "${dstdir}" && tar xzf /var/tmp/base.txz && tar xzf /var/tmp/kernel.txz
      echo "done."                                                        >&3
      echo "------------------------------------------------------------" >&3

      # Update FreeBSD
      if [ "#{$freebsd_version_upgrade}" == 'no' ]
      then
        echo "------------------------------------------------------------" >&3
        echo "Updating FreeBSD #{$freebsd_version} in ${dstdir} ... "       >&3
        freebsd-update fetch --not-running-from-cron -b ${dstdir}
        freebsd-update install --not-running-from-cron -b ${dstdir}
        echo "done."                                                        >&3
        echo "------------------------------------------------------------" >&3
      fi

      # Install packages
      echo "------------------------------------------------------------" >&3
      echo "Installing packages into ${dstdir} ... "                      >&3
      export ASSUME_ALWAYS_YES="yes"
      export IGNORE_OSVERSION="yes"
      rm -rf /usr/local/etc/pkg/repos
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
      cp /var/vagrant/files/vagrant.pub "${dstdir}/home/vagrant/.ssh/authorized_keys"
      chown -R 1001:1001 "${dstdir}/home/vagrant"
      echo "done."                                                        >&3
      echo "------------------------------------------------------------" >&3

      # Copy config files
      echo "------------------------------------------------------------" >&3
      echo "Performing final configuration in ${dstdir} ... "             >&3
      cp "/var/vagrant/files${dstdir}/fstab" "${dstdir}/etc"
      cp "/var/vagrant/files${dstdir}/rc.conf" "${dstdir}/etc"
      cp "/var/vagrant/files${dstdir}/loader.conf" "${dstdir}/boot"
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
