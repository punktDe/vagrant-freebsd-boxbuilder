Vagrant project to generate FreeBSD based Vagrant boxes with ZFS and UFS
========================================================================

For the impatient
-----------------
````
git clone git@github.com:punktDe/vagrant-freebsd-boxbuilder.git
cd vagrant-freebsd-boxbuilder
vagrant up
vagrant halt
./package.sh
cd test
./test.sh
````

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

How's it work?
--------------
Use `vgrant up` or `vagrant provision` (on subsequent runs) to:

* Deploy and start the named build box.
* Create second and third HDD via `VBoxManage`.
* Checkout (first run) or update (consecutive runs) FreeBSD source tree.
* Compile userland and kernel if necessary.
* Create ZFS, install, add config files and `vagrant` user on second hard disk.
* Create UFS, [...] on third hard disk.
* Install some packages on both disks.

When the job is finished use `vagrant halt` followed by `./package.sh` script to create `.box` files from the disk images.

Use `cd test; ./test.sh` to deploy and boot both boxes, so you can check if everything is
consistent. Boxes will be destroyed automatically after you log out again.

Useful info
-----------
* On subsequent `vagrant provision` runs the compile stage is skipped if there
  are no changes to `/usr/src/UPDATING`.
* When making changes, shutdown via `vagrant halt` before each new `vagrant provision`.

Major version ugrade
---------------------
* Keep e.g. 12.2 as the `$build_box` and set `$freebsd_version` to 13.0
* Build the project - this will lead to a 13.0 box with 12.2 packages installed
* Use this box as the new `$build_box` and build again
* XXX - This might fail if a `mergemaster -p` is required. To remedy:
  * SSH into the box, run `mergemaster -p`
  * `vagrant halt`
  * `vagrant up`
  * `vagrant provision`
