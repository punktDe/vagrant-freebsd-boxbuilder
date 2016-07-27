Vagrant project to generate FreeBSD based empty Vagrant boxes, one with ZFS, one with UFS
=========================================================================================

Usage
-----
````
git clone git@gitlab.pluspunkthosting.de:devops/vagrant-freebsd-boxbuilder.git
cd vagrant-freebsd-boxbuilder
vagrant up || vagrant up
vagrant halt
./package.sh
````
The very first `vagrant up` may take a long time, because it runs freebsd-update - be patient.

Files
-----
* `Vagrantfile` - how to start and provision the box
* `files/*` - config files that are copied into the final box

Parameters to tweak
-------------------
In _Vagrantfile_:

* `$build_box` - which box (preferably Hashicorp's) to use for building
* `$freebsd_version` - which FreeBSD version to install in the target boxes
* `${zfs|ufs}_disk_size` - size of hard disk for respective target box
* `${zfs|ufs}_swap_size` - swap size for respective target box

How's it work?
--------------
* Deploy and start Hashicorp's standard FreeBSD box.
* Create second and third HDD via `VBoxManage`.
* Checkout (first run) or update (consecutive runs) FreeBSD source tree.
* Compile userland and kernel if necessary (with VIMAGE support).
* Create ZFS, install, add config files and `vagrant` user on second hard disk.
* Create UFS, [...] on third hard disk.
* Install some packages from standard FreeBSD repository on both disks.
* Use `vagrant halt` followed by `package.sh` script to create `.box` files from disk images.

Useful stuff
------------
* On subsequent `vagrant provision` runs the compile stage is skipped if there are no changes to `/usr/src/UPDATING`.
* When making changes, shutdown via `vagrant halt` before each new `vagrant provision`.

ToDo
----
* Find a place for the box to reside for download via HTTPS.
