Vagrant project to generate FreeBSD based Vagrant boxes with ZFS and UFS
========================================================================

For the impatient
-----------------

```sh
git clone git@github.com:punktDe/vagrant-freebsd-boxbuilder.git
cd vagrant-freebsd-boxbuilder
vagrant up
vagrant halt
./package.sh
cd test
./test.sh
```

Networking considerations
-------------------------

VirtualBox reserves the `192.168.56.0/21` range of IPv4 addresses for host-only networking.
The default address of the box in this project is `192.168.57.57`. If that collides
with your local infrastructure set a different one in the [Vagrantfile](Vagrantfile). Make sure
not to pick the lowest one in the respective network, which is reserved for the host by VirtualBox.

For more details see the relevant [VirtualBox documentation](https://www.virtualbox.org/manual/ch06.html#network_hostonly).

Files
-----

* `Vagrantfile` - how to start and provision the box
* `files/*` - config files that are copied into the final box
* `test/test.sh` - small test shellscript that provisions both boxes, logs you
 in via ssh, then destroys them again

Parameters to tweak
-------------------

In _Vagrantfile_:

* `$build_box` - which box to use for building
* `$build_cores` - how many cores to use for building
* `$freebsd_version` - which FreeBSD version to install in the target boxes
* `$initial_package_list` - which packages you want in your box by default
* `${zfs|ufs}_disk_size` - size of hard disk for respective target box
* `${zfs|ufs}_swap_size` - swap size for respective target box

How does it work?
-----------------

Use `vagrant up` or `vagrant provision` (on subsequent runs) to:

* Deploy and start the named build box.
* Create second and third HDD via `VBoxManage`.
* Create ZFS, install, add config files and `vagrant` user on second hard disk.
* Create UFS, [...] on third hard disk.
* Install FreeBSD in the configured version to the destination disks.
* Run `freebsd-update` on both installations.
* Install some packages on both disks.

When the job is finished use `vagrant halt` followed by `./package.sh` script to create `.box` files from the disk images.

Use `cd test; ./test.sh` to deploy and boot both boxes, so you can check if everything is
consistent. Boxes will be destroyed automatically after you log out again.

Useful info
-----------

* When making changes, shutdown via `vagrant halt` before each new `vagrant up --provision`.

Major version upgrade
---------------------

* Keep e.g. 13.2 as the `$build_box` and set `$freebsd_version` to "14.0"
* Set `$freebsd_version_upgrade` to "yes"
* Build the project - this will lead to a 14.0 box with 13.2 packages installed
* Manually import this box, it as the new `$build_box` and build again
