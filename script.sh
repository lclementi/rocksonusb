#!/bin/sh
#
# wipe all the data from a USB key and install the 
# rocks installer on it
#
# Luca Clementi


iso=$1
usb_dev=$2
usb_mount=/mnt/mytemporarymntusb
iso_mount=/mnt/mytemporarymntiso
mbr=/usr/share/syslinux/mbr.bin

if [ ! -f "$iso" ]; then 
	echo $iso must be a valid iso file
	exit 1
fi

if [ ! -b "$usb_dev" ]; then
	echo $usb_dev must be a valid block device
	exit 1
fi



if [ ! -f "$mbr" ]; then 
	echo "you need to install syslinux (yum install syslinux)"
	exit 1
fi


#wipe the partition table
dd if=/dev/zero of=$usb_dev bs=1M count=1
echo -e "o\nn\np\n1\n\n\nt\nc\na\n1\nw\n" | fdisk $usb_dev
# drop the MBR
dd conv=notrunc bs=440 count=1 if=$mbr of=${usb_dev}
# rescan and partition
partprobe $usb_dev
mkfs.vfat ${usb_dev}1

#mount usb
mkdir -p $usb_mount
mount ${usb_dev}1 $usb_mount

#mount iso
mkdir -p $iso_mount
mount -o loop ${iso} $iso_mount


cp -a $iso_mount/isolinux/* $usb_mount/
cp -a $iso_mount/kernel $usb_mount/
cp $iso_mount/ks.cfg $usb_mount/

echo -e "var.trackers = 127.0.0.1\nvar.pkgservers = 127.0.0.1\n" > \
	$usb_mount/rocks.conf

cd $usb_mount
rm isolinux.bin boot.cat TRANS.TBL
mv isolinux.cfg syslinux.cfg

blk_id=`blkid ${usb_dev}1 |awk '{print $2}' | tr -d '"'`
rocks_version=`ls $iso_mount/kernel | grep "[0-9]\.[0-9]"`
echo Fixing grub menu for Rocks $rocks_version with blkid $blk_id

sed -i "s/ks=cdrom:\/ks.cfg/ks=hd:$blk_id:\/ks.cfg repo=hd:$blk_id:\/kernel\/$rocks_version\/x86_64/g"  syslinux.cfg

sed -i "/url/d" ks.cfg

cd -
#umount everything
umount $usb_mount
umount $iso_mount
syslinux ${usb_dev}1

echo Done!


