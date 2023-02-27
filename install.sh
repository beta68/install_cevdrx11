#!/bin/sh

#
# this script installs VDR base system within a CoreElec
# environment. simply invoke chmod 775 ./install.sh && ./install.sh
# (c) 2023 Rudi Follmann
# payload is the base64 decoded package list to be installed
# attention: everything is done as root. therefore, be careful
#

#
# define download files and githubs
#
UBUNTUIMAGE="https://de.eu.odroid.in/ubuntu_20.04lts/n2/ubuntu-20.04-4.9-minimal-odroid-n2-20220228.img.xz"
OPENGLMESON="https://github.com/CoreELEC/opengl-meson"
VDRREPO="git://git.tvdr.de/vdr.git"
JOJO61="https://github.com/jojo61/vdr-plugin-softhdodroid"
EXTERNALPLAYER="https://git.uli-eckhardt.de/vdr-plugin-externalplayer.git"

#--------------------------------------------------------------
#------------ NO CHANGES BEYOND THIS POINT --------------------
#--------------------------------------------------------------

# define the tasks that need to be done with the extracted content
process_tar() {
    cd $WORK_DIR
    # option to do something with the content
}

echo ""
echo "This script will install a chroot environment with VDR and X11"
echo "under CoreElec installation. (c) by Rudi Follmann 2023."
echo "Use CoreElec on MINIMUM 16GB free installation space."
read -n 1 -s -r -p "Press any key to continue or CTRL-c to exit..."
echo ""
echo ""

#
# check availability of all files
#
echo -n "Checking availability of UBUNTU image: " 
AVAILABLE=$(wget --spider -S $UBUNTUIMAGE  2>&1 | awk '{print $NF}' | grep exists)
if [ ! -z "$AVAILABLE" ]; 
then
 echo "OK"
else
 echo "Not found. Exiting..."
fi

echo -n "Checking availability of CE opengl-meson: " 
AVAILABLE=$(curl -s -o /dev/null -I -w "%{http_code}" $OPENGLMESON)
if [ "404" != $AVAILABLE ];
then
 echo "OK"
else
 echo "Not found. Exiting..."
fi	

echo -n "Checking availability of VDR repository: "                                                                            
AVAILABLE=$(curl -s -o /dev/null -I -w "%{http_code}" $VDRREPO)                                                             
if [ "404" != $AVAILABLE ];                                                                                                     
then                                                                                                                         
 echo "OK"                                                                                                                   
else                                                                                                                                                                
 echo "Not found. Exiting..."                                                                                                                                      
fi 

echo -n "Checking availability of softhdodroid repository: "                                        
AVAILABLE=$(curl -s -o /dev/null -I -w "%{http_code}" $JOJO61)                                    
if [ "404" != $AVAILABLE ];                                                                                                          
then                                                                                                                       
 echo "OK"                                                                                                           
else                                                                                                                         
 echo "Not found. Exiting..."                                                              
fi

echo -n "Checking availability of externalplayer repository: "                                                                    
AVAILABLE=$(curl -s -o /dev/null -I -w "%{http_code}" $EXTERNALPLAYER)                                                                  
if [ "404" != $AVAILABLE ];                                                                                                                                                   
then                                                                                                                                                                          
 echo "OK"                                                                                                                      
else                                                                                                                            
 echo "Not found. Exiting..."                                                                                                                        
fi

# get Odroid N2 minimal UBUNTU 20.04 image and extract rootfs
wget $UBUNTUIMAGE 
echo "Unzipping Ubuntu image. Please wait..."
xz -d ubuntu-20.04-4.9-minimal-odroid-n2-20220228.img.xz
losetup -Pf ubuntu-20.04-4.9-minimal-odroid-n2-20220228.img
mkdir UBUNTU 
mount /dev/loop1p2 UBUNTU 
rm UBUNTU/aafirstboot
tar cvf rootfs.tar UBUNTU/*
umount UBUNTU
losetup -d /dev/loop1
tar xvf rootfs.tar
rm rootfs.tar
rm ubuntu-20.04-4.9-minimal-odroid-n2-20220228.img
# make some directories and link network in chroot to CE network
rm UBUNTU/etc/resolv.conf
mkdir UBUNTU/storage
mkdir UBUNTU/ce
mkdir UBUNTU/video
ln -s /ce/etc/resolv.conf UBUNTU/etc/resolv.conf

# umount filesystem in case they have already been mounted
umount /storage/UBUNTU/dev/pts
umount /storage/UBUNTU/proc
umount /storage/UBUNTU/dev
umount /storage/UBUNTU/sys
umount /storage/UBUNTU/run
umount /storage/UBUNTU/ce
umount /storage/UBUNTU/storage

# mount files system for chroot
mount -t proc none /storage/UBUNTU/proc
mount -o bind /dev /storage/UBUNTU/dev
mount -o bind /dev/pts /storage/UBUNTU/dev/pts
mount -o bind /sys /storage/UBUNTU/sys
mount -o bind / /storage/UBUNTU/ce
mount -o bind /storage /storage/UBUNTU/storage
mount -o bind /run /storage/UBUNTU/run

# set chroot executable path
UPATH='/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin'

# update package list and perform upgrade
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH apt update"
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH apt -y upgrade"

mkdir -p UBUNTU/home/user/package_list

# line number where payload starts. payload is package list to be installed
PAYLOAD_LINE=$(awk '/^__PAYLOAD_BEGINS__/ { print NR + 1; exit 0; }' $0)

# directory where a tarball is to be extracted
WORK_DIR=/storage/UBUNTU/home/user/package_list

# extract the embedded tar file
tail -n +${PAYLOAD_LINE} $0 | openssl base64 -d | tar -jpvx -C $WORK_DIR

# install all required packages according to extracted package list
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH xargs -a '/storage/UBUNTU/home/user/package_list/packages.list' apt -y install"
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH apt -y purge packagekit"
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH apt -y autoremove"

# clone meson directory and and install correct libMali.so for chroot
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH git clone $OPENGLMESON /storage/UBUNTU/home/user/opengl-meson"

MALI="$(ls -l /var/lib/libMali.so | awk {'print$NF'})"
#echo $MALI
case "$MALI" in 
  *gondul*)
    cp /storage/UBUNTU/home/user/opengl-meson/lib/arm64/gondul/r12p0/fbdev/libMali.so /storage/UBUNTU/usr/lib/aarch64-linux-gnu/
    ;;
esac
case "$MALI" in
  *dvalin*)
    cp /storage/UBUNTU/home/user/opengl-meson/lib/arm64/dvalin/r12p0/fbdev/libMali.so /storage/UBUNTU/usr/lib/aarch64-linux-gnu/
    ;;
esac
case "$MALI" in
  *m450*)
    cp /storage/UBUNTU/home/user/opengl-meson/lib/arm64/m450/r7p0/fbdev/libMali.so /storage/UBUNTU/usr/lib/aarch64-linux-gnu/
    ;;
esac

# clone VDR from Klaus website
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH git clone $VDRREPO /storage/UBUNTU/home/user/vdr"
# make lib directory for old plugins
mkdir -p /storage/UBUNTU/home/user/vdr/PLUGINS/lib
# clone jojo61 output plugin for Amlogic devices
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH git clone $JOJO61 /storage/UBUNTU/home/user/vdr/PLUGINS/src/softhdodroid"

# make VDR and output plugin and install them
# two times required, if skindesigner needs to be installed (not here)
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH make -j4 -C /storage/UBUNTU/home/user/vdr"                
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH make -j4 -C /storage/UBUNTU/home/user/vdr install"
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH cp -r /storage/UBUNTU/home/user/vdr/PLUGINS/lib/* /storage/UBUNTU/usr/local/lib/vdr"
#chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH make -j4 -C /storage/UBUNTU/home/user/vdr/PLUGINS/src/skindesigner clean"
#chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH make -j4 -C /storage/UBUNTU/home/user/vdr/PLUGINS/src/skindesigner"
#chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH make -j4 -C /storage/UBUNTU/home/user/vdr/PLUGINS/src/skindesigner install"
#chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH make -j4 -C /storage/UBUNTU/home/user/vdr"                
#chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH make -j4 -C /storage/UBUNTU/home/user/vdr install" 

# make directory to store all scripts
mkdir -p /storage/UBUNTU/vdr

# loopermabilight script
echo '#!/bin/bash

sleep 10

PFAD=/storage/UBUNTU/vdr

cd /storage/UBUNTU/vdr
NEXT=ambion;

while true;
do
   case "$NEXT" in
  "ambioff")
       ./looperambi
       systemctl stop service.hyperion.ng 
       NEXT=ambion;
       ;;
   "ambion")
       ./looperambi
       systemctl start service.hyperion.ng
       NEXT=ambioff;
       ;;
    esac
done' > /storage/UBUNTU/vdr/ambitoggle
chmod 775 /storage/UBUNTU/vdr/ambitoggle

# loop script
echo '#!/bin/bash

while true;
do
  sleep 300
done' > /storage/UBUNTU/vdr/looper
chmod 775 /storage/UBUNTU/vdr/looper

# we have several loopers
cp /storage/UBUNTU/vdr/looper /storage/UBUNTU/vdr/looperambi
cp /storage/UBUNTU/vdr/looper /storage/UBUNTU/vdr/looperreboot
cp /storage/UBUNTU/vdr/looper /storage/UBUNTU/vdr/loopershutdown
cp /storage/UBUNTU/vdr/looper /storage/UBUNTU/vdr/looperx11

# reboot script
echo '#!/bin/bash

sleep 5

PFAD=/storage/UBUNTU/vdr

cd /storage/UBUNTU/vdr
NEXT=ambion;

while true;
do
   case "$NEXT" in
  "ambioff")
       ./looperambi
       systemctl stop service.hyperion.ng 
       NEXT=ambion;
       ;;
   "ambion")
       ./looperreboot
       reboot   
       NEXT=ambioff;
       ;;
    esac
done' > /storage/UBUNTU/vdr/reboot.sh
chmod 775 /storage/UBUNTU/vdr/reboot.sh

# shutdown script
echo '#!/bin/bash

sleep 10
./loopershutdown

#halt -p' > /storage/UBUNTU/vdr/shutdown
chmod 775 /storage/UBUNTU/vdr/shutdown

# script to toggle between VDR and KODI
echo '#!/bin/bash

sleep 10 

PFAD=/storage/UBUNTU/vdr

cd /storage/UBUNTU/vdr
NEXT=vdr;

while true;
do
   case "$NEXT" in
  "xbmc")
        systemctl unmask kodi
        systemctl start kodi
        systemctl mask kodi
        sleep 3
        while ps axg | grep -vw grep | grep -w kodi.bin > /dev/null  ||  ps axg | grep -vw grep | grep -w emulationstation > /dev/null ; do sleep 2; done

       systemctl stop kodi
       $PFAD/svdrpsend.sh REMO on 
       $PFAD/svdrpsend.sh PLUG softhdodroid ATTA -a hw:CARD=AMLAUGESOUND,DEV=0
       NEXT=vdr;
       ;;
   "vdr")
       ./looper
       $PFAD/svdrpsend.sh PLUG softhdodroid DETA
       $PFAD/svdrpsend.sh REMO off
       NEXT=xbmc;           
       ;;                   
    esac
done' > /storage/UBUNTU/vdr/softoggle
chmod 775 /storage/UBUNTU/vdr/softoggle

# VDR communication script svdrpsend
echo '#!/bin/sh
export PATH='/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin'
chroot /storage/UBUNTU ./usr/local/bin/svdrpsend "$@"' > /storage/UBUNTU/vdr/svdrpsend.sh
chmod 775 /storage/UBUNTU/vdr/svdrpsend.sh

# main vdr script
echo '#!/bin/sh

# mount devpts for ssh
mount devpts /dev/pts -t devpts

# BOOT = X11
#killall splash-image
#systemctl stop service.hyperion.ng.service 
# alles mounten (siehe unten)
# und dann startx.sh starten
#exit

do_mount() {
mount -t proc none /storage/UBUNTU/proc
mount -o bind /dev /storage/UBUNTU/dev
mount -o bind /dev/pts /storage/UBUNTU/dev/pts
mount -o bind /sys /storage/UBUNTU/sys
mount -o bind / /storage/UBUNTU/ce
mount -o bind /storage /storage/UBUNTU/storage
mount -o bind /run /storage/UBUNTU/run
}

sleep 3 
killall splash-image

#switch off ambilight by default to save power
systemctl stop service.hyperion.ng

# BOOT = KODI oder BOOT = VDR
# hier weiter
[ ! -d "/storage/UBUNTU/dev/usb" ] && do_mount

export PATH='/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin'
chroot /storage/UBUNTU /home/user/runvdr &' > /storage/UBUNTU/vdr/vdr.sh
chmod 775 /storage/UBUNTU/vdr/vdr.sh

# VDR shutdown enable script
echo '#!/bin/bash

sleep 5

PFAD=/storage/UBUNTU/vdr

cd /storage/UBUNTU/vdr
NEXT=ambion;

while true;
do
   case "$NEXT" in
  "ambioff")
       ./looperambi
       systemctl stop service.hyperion.ng 
       NEXT=ambion;
       ;;
   "ambion")
       ./loopershutdown
        halt -p
       NEXT=ambioff;
       ;;
    esac
done' > /storage/UBUNTU/vdr/shutdown.sh
chmod 775 /storage/UBUNTU/vdr/shutdown.sh

# x11 start script
echo '#!/bin/bash

PFAD=/storage/UBUNTU/vdr

cd /storage/UBUNTU/vdr
NEXT=ambion;

while true;
do
   case "$NEXT" in
  "ambioff")
       ./looperambi
       systemctl stop service.hyperion.ng 
       NEXT=ambion;
       ;;
   "ambion")
       ./looperx11
       systemctl stop vdr.service
       chroot /storage/UBUNTU /home/user/startx.sh &
       while true; do sleep 10; done
       ;;
    esac
done' > /storage/UBUNTU/vdr/x11.sh
chmod 775 /storage/UBUNTU/vdr/x11.sh

# runvdr script
echo '#!/bin/bash

# raxda zero does not have a RTC
# comment this in for Odroid N2(+)

#sudo hwclock --systohc --utc
#NextTimer=$(($1 - 600 ))  # 10 minutes earlier
#
#sudo bash -c "echo 0 > /sys/class/rtc/rtc0/wakealarm"
#sudo bash -c "echo $NextTimer > /sys/class/rtc/rtc0/wakealarm"

#switch targa display off
#svdrpsend PLUG targavfd OFF

# usual way but not for ARM
#sudo /sbin/poweroff
##sudo halt -p
#WOL:
#sudo systemctl suspend

# CoreElec: kill loopershutdown to shut down from host
# not required for Radxa zero but for Odroid
#killall loopershutdown

# Radxa Zero (2)
# detach output device. this will still allow vdr to record TV
svdrpsend REMO off
svdrpsend PLUG softhdodroid DETA
# allow to switch it on again using remot control
at -f /home/user/on.sh now' > /storage/UBUNTU/usr/local/bin/vdrshutdown.sh
chmod 775 /storage/UBUNTU/usr/local/bin/vdrshutdown.sh

# generate runvdr script
cat <<'EOF' > /storage/UBUNTU/home/user/runvdr 
#!/bin/sh

#export LC_MESSAGES=de_DE.UTF-8
#export LC_LANG=de_DE.UTF-8
#export LANG=de_DE.UTF-8
#export LC_ALL=de_DE.UTF8
#export VDR_LANG=de_DE@euro
#export VDR_CHARSET_OVERRIDE=ISO-8859-9

# assume 4K TV. If not, Full HD
RESOLUTION="2160p50hz"
if [ "$(cat /sys/class/amhdmitx/amhdmitx0/disp_cap | grep 2160p50hz)" = $RESOLUTION ];
then
        RES_FROM="1080p50hz"
        RESOLUTION="2160p50hz420"
else
        RES_FROM="1080p60hz"
        RESOLUTION="1080p50hz"
fi

#echo 420,10bit > /sys/class/amhdmitx/amhdmitx0/attr
#echo 1080p50 > /sys/class/display/mode
#echo 2160p50 > /sys/class/display/mode

# use autoselect 4k/1080p
echo $RES_FROM > /sys/class/display/mode
sleep 1
#echo 2160p50 > /sys/class/display/mode
echo $RESOLUTION > /sys/class/display/mode

# not needed
#echo 0 > /sys/class/video/blackout_policy
#echo 3 > /sys/module/amvdec_h265/parameters/double_write_mode
#echo 3 > /sys/module/amvdec_vp9/parameters/double_write_mode

# keeps ssh alive after vdrkill
umount /dev/pts/
mount devpts /dev/pts -t devpts

#start atd
atd

#mount /dev/mmcblk1p1 /video

# change to virtual terminal to control VDR from there
# this is required for FLIRC only

# check if FLIRC is avaiable
if [ "$(lsusb | grep Clay | awk '{print $(NF-1)}')" = 'Clay' ];
then
	# only change terminal, if FLIRC is connected
        TERMINAL="-t /dev/tty7"
        /bin/chvt 7
else
	TERMINAL=""
fi

VDRPRG="DISPLAY=:0.0 /usr/local/bin/vdr"

#VDROPTIONS="-D 0 -w 60 -l 0 -v /video -s /usr/local/bin/vdrshutdown.sh"
#VDROPTIONS="-l 0 -w 60 --lirc=/var/run/lirc/lircd -v /video -s /usr/local/bin/vdrshutdown.sh"

# FLIRC requires a terminal to control VDR from
# This has been set to 7 above
VDROPTIONS="$TERMINAL -l 0 --lirc -w 60  -v /video -c /var/lib/vdr -s /usr/local/bin/vdrshutdown.sh"
#VDROPTIONS="-l 0 --lirc -w 60  -v /video -c /var/lib/vdr -s /usr/local/bin/vdrshutdown.sh"
#VDROPTIONS="-l 0 -w 60  -v /video -c /var/lib/vdr -s /usr/local/bin/vdrshutdown.sh"
# For other options see manpage vdr.1

# Start in detach-mode. svdrpsend PLUG softhddrm ATTA will attach
# This will be done by a watchdog that kills itself once TV has been switched on

# start softhdodroid in detach mode, if kodi is running (e.g. vdr if crashes during KODI)
if pgrep kodi.bin >/dev/null 2>&1
then
	OUTPUT="-P'softhdodroid -a hw:CARD=AMLAUGESOUND,DEV=0 -D'"
else
	OUTPUT="-P'softhdodroid -a hw:CARD=AMLAUGESOUND,DEV=0'"
fi

VDRPLUGINS1="  \
"
# OUTPUT PLUGIN here
VDRPLUGINS2=" \
-P'externalplayer' \
"


#VDRCMD="nohup sh -c '$VDRPRG $VDROPTIONS $VDRPLUGINS $*' > /dev/null 2> /dev/null < /dev/null"
VDRCMD="$VDRPRG $VDROPTIONS $VDRPLUGINS1 $OUTPUT $VDRPLUGINS2 $*"

KILL="/usr/bin/killall -q -TERM"

# Detect whether the DVB driver is already loaded
# and return 0 if it *is* loaded, 1 if not:
DriverLoaded()
{
  return 1
}

# Load all DVB driver modules needed for your hardware:
LoadDriver()
{
  return 0
}

# Unload all DVB driver modules loaded in LoadDriver():
UnloadDriver()
{
  return 0
}

# Load driver if it hasn't been loaded already:
if ! DriverLoaded; then
   LoadDriver
   fi

while (true) do
      eval "$VDRCMD"
#      if test $? -eq 0 -o $? -eq 2; then /usr/local/bin/hyperion_stop; pkill runvdr; exit; fi
      if test $? -eq 0 -o $? -eq 2; then exit; fi      
      echo "`date` reloading DVB driver"
      $KILL $VDRPRG
#      sleep 5
      UnloadDriver
      LoadDriver
      echo "`date` restarting VDR"
      done
EOF
chmod 775 /storage/UBUNTU/home/user/runvdr

# switch radxa zero (2) on with FLIRC
# code must be adapted
cat <<'EOF' > /storage/UBUNTU/home/user/on.sh
#!/bin/bash

# change this for other FLIRC
#device='/dev/input/event2'

# test autodetect FLIRC
EVENT=$(ls -l /dev/input/by-path | grep kbd | awk '{print $NF}' | tail -c7)
device='/dev/input/'$EVENT

# change power-on-code regarding FLIRC configuration
event_power='*code 40 (KEY_APOSTROPHE), value 1*'

evtest "$device" | while read line; do
  case $line in
    ($event_power) svdrpsend REMO on; svdrpsend PLUG softhdodroid ATTA; svdrpsend HITK OK; killall evtest; exit ;;
  esac
done
EOF
chmod 775 /storage/UBUNTU/home/user/on.sh

# start x11. call vdrbyebye.sh on home directory
# can be added to VDR coomands.conf file
cat <<'EOF' > /storage/UBUNTU/home/user/startx.sh
#!/bin/bash

# restart atd (has been closed with closed runvdr)
atd

# switch resolution to finally 1080p50hz
echo 2160p50 > /sys/class/display/mode
sleep 1
echo 1080p50hz > /sys/class/display/mode
sleep 1

# bind to virtual terminal 8, start X and windows-manager
# important: use 16bit only, otherwise does not work
chvt 8
sleep 1
echo "/bin/sh -c 'DISPLAY=:0.0 /usr/bin/X -depth 16'" | at now
#echo "/bin/sh -c 'DISPLAY=:0.0 /usr/bin/X -depth 24'" | at now
sleep 1
#echo "/bin/sh -c 'cd /home/user && HOME=/home/user PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin DISPLAY=:0.0 /usr/bin/jwm'" | at now
echo "/bin/sh -c 'cd /home/user && HOME=/home/user PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin DISPLAY=:0.0 LANG=de_DE.UTF-8 /usr/bin/dbus-launch /usr/bin/lxsession'" | at now
sleep 1

# required after x11 start, otherwise display may turn black upon youtube 4k videos
echo 1080p60hz > /sys/class/display/mode

# pulseaudio is used by CE
killall pulseaudio
sleep 1
echo "/bin/sh -c 'HOME=/home/user PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin DISPLAY=:0.0 pulseaudio --exit-idle-time=-1 -D'" | at now
EOF
chmod 775 /storage/UBUNTU/home/user/startx.sh

# kills VDR and starts X11
cat <<'EOF' > /storage/UBUNTU/home/user/vdrbyebye.sh
#!/bin/bash

killall looperx11
EOF
chmod 775 /storage/UBUNTU/home/user/vdrbyebye.sh

# ubuntu chroot script without VDR start
# exit on vdr.sh in this case
cat <<'EOF' > /storage/ubuntu.sh
#!/bin/sh
umount /storage/UBUNTU/dev/pts
umount /storage/UBUNTU/proc
umount /storage/UBUNTU/dev
umount /storage/UBUNTU/sys
umount /storage/UBUNTU/run
umount /storage/UBUNTU/ce
umount /storage/UBUNTU/storage

modprobe amlcm
modprobe videobuf-res
modprobe amlvideodri

mount -t proc none /storage/UBUNTU/proc
mount -o bind /dev /storage/UBUNTU/dev
mount -o bind /dev/pts /storage/UBUNTU/dev/pts
mount -o bind /sys /storage/UBUNTU/sys
mount -o bind / /storage/UBUNTU/ce
mount -o bind /storage /storage/UBUNTU/storage
mount -o bind /run /storage/UBUNTU/run
EOF
chmod 775 /storage/ubuntu.sh

# nice bashrc script
cat <<'EOF' > /storage/.bashrc
export PATH='/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin'
export LS_OPTIONS='--color=auto'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'

PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\w \$\[\033[00m\] '

export HOME=/home/user
cd /home/user
alias 'll=ls -l'
#
#curl wttr.in/Berlin
#
echo "  _   _ ____  _   _ _   _ _____ _   _        _                     _   "
echo " | | | | __ )| | | | \ | |_   _| | | |   ___| |__  _ __ ___   ___ | |_ "
echo " | | | |  _ \| | | |  \| | | | | | | |  / __| '_ \| '__/ _ \ / _ \| __|"
echo " | |_| | |_) | |_| | |\  | | | | |_| | | (__| | | | | | (_) | (_) | |_ "
echo "  \___/|____/ \___/|_| \_| |_|  \___/   \___|_| |_|_|  \___/ \___/ \__|"
echo ""
EOF

# ambilight service script
# requires an installed hyperion.ng
cat <<'EOF' > /storage/.config/system.d/ambitoggle.service
[Unit]
Description=Toggle Ambilight between on and off

[Service]
#Type=oneshot
Requires=network-online.service
After=network-online.service
ExecStart=/storage/UBUNTU/vdr/ambitoggle 
#Restart=never
#RestartSec=15

[Install]
WantedBy=kodi.target
EOF
chmod 775 /storage/.config/system.d/ambitoggle.service

# reboot service script (from VDR)
cat <<'EOF' > /storage/.config/system.d/reboot.service
[Unit]
Description=Allows VDR to reboot computer

[Service]
#Type=oneshot
Requires=network-online.service
After=network-online.service
ExecStart=/storage/UBUNTU/vdr/reboot.sh 
#Restart=never
#RestartSec=15

[Install]
WantedBy=kodi.target
EOF
chmod 775 /storage/.config/system.d/reboot.service

# shutdown service script (from VDR)
cat <<'EOF' > /storage/.config/system.d/shutdown.service
[Unit]
Description=Allows VDR to shutdown computer

[Service]
#Type=oneshot
Requires=network-online.service
After=network-online.service
ExecStart=/storage/UBUNTU/vdr/shutdown.sh 
#Restart=never
#RestartSec=15

[Install]
WantedBy=kodi.target
EOF
chmod 775 /storage/.config/system.d/shutdown.service

# toggle service script (KODI <-> VDR)
cat <<'EOF' > /storage/.config/system.d/softoggle.service
[Unit]
Description=Toggle betwen Kodi and VDR

[Service]
#Type=oneshot
Requires=network-online.service
After=network-online.service
ExecStart=/storage/UBUNTU/vdr/softoggle 
#Restart=never
#RestartSec=15

[Install]
WantedBy=kodi.target
EOF
chmod 775 /storage/.config/system.d/softoggle.service

# VDR service script
cat <<'EOF' > /storage/.config/system.d/vdr.service
[Unit]
Description=Start VDR

[Service]
Type=forking
Requires=network-online.service
After=network-online.service
ExecStart=/storage/UBUNTU/vdr/vdr.sh
Restart=always
RestartSec=15

[Install]
WantedBy=kodi.target
EOF
chmod 775 /storage/.config/system.d/vdr.service

# x11 service script
cat <<'EOF' > /storage/.config/system.d/x11.service
[Unit]
Description=Starts and stops kodi (required for x11 usage)

[Service]
Type=forking
Requires=network-online.service
After=network-online.service
ExecStart=/storage/UBUNTU/vdr/x11.sh
RemainAfterExit=true
Type=oneshot

[Install]
WantedBy=kodi.target
EOF
chmod 775 /storage/.config/system.d/x11.service

# enable all services required for VDR
systemctl enable ambitoggle.service
systemctl enable reboot.service
systemctl enable shutdown.service
systemctl enable softoggle.service
systemctl enable vdr.service
systemctl enable x11.service

# clone and install externalplayer to switch between VDR and KODI (and back)
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH git clone $EXTERNALPLAYER /storage/UBUNTU/home/user/vdr/PLUGINS/src/externalplayer"
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH make -j4 -C /storage/UBUNTU/home/user/vdr"
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH make -j4 -C /storage/UBUNTU/home/user/vdr install"

mv /storage/UBUNTU/var/lib/vdr/plugins/externalplayer/externalplayer.conf /storage/UBUNTU/var/lib/vdr//plugins/externalplayer/externalplayer.conf.orig

cat <<'EOF' > /storage/UBUNTU/var/lib/vdr//plugins/externalplayer/externalplayer.conf
{
MenuEntry = "KODI";
Command = "/usr/bin/killall looper";
OutputMode = extern;
InputMode = normal; # XBMC should be configured for LIRC.
}
EOF

cat <<'EOF' > /storage/.kodi/userdata/advancedsettings.xml
<advancedsettings version="1.0">
	<showexitbutton>true</showexitbutton>
	<cache>
    		<buffermode>1</buffermode>
    		<memorysize>339460608</memorysize>
    		<readfactor>20</readfactor>
  	</cache>
</advancedsettings>
EOF

# mask kodi. we start with VDR first
systemctl mask kodi

# configure correct time zone fpr chroot environment
chroot /storage/UBUNTU /bin/bash -c "PATH=$UPATH dpkg-reconfigure tzdata"

# get bluray keys
mkdir -p /storage/.config/aacs
curl -k https://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg -o /storage/.config/aacs/KEYDB.cfg 

# leave script
# DO NOT CHANGE beyond this point. contains package list as payload
exit 0
__PAYLOAD_BEGINS__
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
