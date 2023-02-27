# install_cevdrx11

Unzip the instatll-script, copy it to CoreElec /storage directory and execute it: ./install.sh. The script will download an Ubuntu 20.04 image, extract the rootfs, update it and install missing packages required for VDR and X11. The package list is provided as a base64 encoded tar.bz2-payload within the script.

The user needs to press ENTER several times during installation and finally select the time zone for chroot environment. The script should work on any Amlogic hardware which CE itself is running on. libMali.so-detection is implemented. Network configuration is done automatically. The script will boot into VDR after installation (please reboot). Services are added in /storage/.config/system.d. Scripts are in /storage/UBUNTU/vdr and in /storage/UBUNTU/home/user. KODI can be called from VDR menu, leaving KODI will enable VDR again. While KODI is running, VDR is running in background and VNSI PVR can be used to connect to VDR. The script /storage/UBUNTU/home/user/vdrbyebye.sh will start X11.

Please use the script with care as everything is installed/handled as root.

For un-installation please perform the following steps:

- disable all new services in /storage/.config/system.d
- put exit as first line in /storage/UBUNTU/vdr.sh and reboot the box
- be sure that rootfs is NOT mounted
- delete UBUNTU directory and remove services files

WARNING: NEVER (!) DELETE UBUNTU WHILE CE FILESYSTEM IS MOUNTED!

The script is CE update safe.

A chroot shell can be started as follows (after installation):

ssh root@ip-of-your-ce-box
cd UBUNTU
chroot . /bin/bash
Afterwards, you can use apt to install/purge packages. If I find the time I may program a KODI addon for this.
