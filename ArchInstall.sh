#!/bin/bash

# Partitioning with parted
parted /dev/sda mklabel gpt
parted /dev/sda mkpart ESP 1MiB 1GiB
parted /dev/sda set 1 esp on
parted /dev/sda mkpart primary 1GiB 16GiB
parted /dev/sda mkpart primary 16GiB 100%

# Reload partition table
partprobe /dev/sda

# Format EFI partition
mkfs.fat -F 32 /dev/sda1

# Format root partition
mkfs.ext4 /dev/sda2

# Setup LVM
vgcreate vg_group /dev/sda3
lvcreate vg_group -L 4G -n SWAP
lvcreate vg_group -L 15G -n lv_home_colleague
lvcreate vg_group -L 5G -n lv_home_son
lvcreate vg_group -L 5G -n lv_shared
lvcreate vg_group -L 10G -n lv_encrypted
lvcreate vg_group -l 100%FREE -n lv_VM

# Encrypt the logical volume
echo "azert123" | cryptsetup luksFormat /dev/vg_group/lv_encrypted
mkswap /dev/vg_group/SWAP
swapon /dev/vg_group/SWAP

# Format file systems
mkfs.ext4 /dev/vg_group/lv_home_colleague
mkfs.ext4 /dev/vg_group/lv_home_son
mkfs.ext4 /dev/vg_group/lv_shared
mkfs.ext4 /dev/vg_group/lv_VM
mkfs.ext4 /dev/sda2

# Mount file systems
mount /dev/sda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi
mkdir -p /mnt/home/colleague
mount /dev/vg_group/lv_home_colleague /mnt/home/colleague
mkdir /mnt/home/son
mount /dev/vg_group/lv_home_son /mnt/home/son
mkdir /mnt/shared
mount /dev/vg_group/lv_shared /mnt/shared
mkdir /mnt/VM
mount /dev/vg_group/lv_VM /mnt/VM

# Enable network card
#systemctl enable systemd-networkd systemd-resolved
#systemctl start systemd-networkd systemd-resolved

#echo -e "[Match]\nName=ens33\n\n[Network]\nDHCP=yes" > /etc/systemd/network/20-wired.network

#systemctl restart systemd-networkd systemd-resolved

# Generate fstab
mkdir /mnt/etc
genfstab -L /mnt >> /mnt/etc/fstab
pacstrap /mnt base linux linux-firmware grub efibootmgr lvm2 nano vim networkmanager

# Chroot into system and configure
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
sed -i "s/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr" > /etc/vconsole.conf
echo "CustomArch" > /etc/hostname
echo "root:azerty123" | chpasswd
sed -i 's/\(HOOKS=(.*\)filesystems/\1lvm2 filesystems/' /etc/mkinitcpio.conf
mkinitcpio -P
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=CustomArchBootLoader
grub-mkconfig -o /boot/grub/grub.cfg
exit

EOF

umount -R /mnt

reboot