Vagrant project to generate FreeBSD/ZFS based empty Vagrant box
===============================================================

Usage
-----
````
git clone git@gitlab.pluspunkthosting.de:devops/vagrant-freebsd-zfs.git
cd vagrant-freebsd-zfs
vagrant up || vagrant up
./package.sh
````

Files
-----
* `Vagrantfile` - how to start and provision the box
* `files/*` - config files that are copied into the final box

Parameters to tweak
-------------------
In _Vagrantfile_:

* `$build_box` - which box (preferably Hashicorp) to use
* `$freebsd_version` - which FreeBSD version to install in the target box
* `$disk_size` - size of hard disk for target box
* `$swap_size` - swap size for target box

How's it work?
--------------
* Deploy and start Hashicorp's standard FreeBSD box.
* Create second HDD via `VBoxManage`.
* Checkout (first run) or update (consecutive runs) FreeBSD source tree.
* Compile userland and kernel if necessary.
* Create ZFS, install, add config files and `vagrant` user.
* Install some packages from standard FreeBSD repository.
* Shutdown when finished.
* Use `package.sh` script to create `.box` file from disk image.

Useful stuff
------------
* On subsequent `vagrant provision` runs the compile stage is skipped, if there are no changes to `/usr/src/UPDATING`.
* When making changes, shutdown via `vagrant halt` before each new `vagrant provision`.

ToDo
----
* Improve ZFS filesystem layout.
* Find a place for the box to reside for download via HTTPS.
