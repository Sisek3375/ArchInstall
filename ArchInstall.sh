#!/bin/bash

# Update system
pacman -Syu --noconfirm

# Hostname of the installed machine.
HOSTNAME='ArchESGI'

# Root password (leave blank to be prompted).
ROOT_PASSWORD='root'

# Main user to create (by default, added to wheel group, and others).
USER_NAME='user'

# The main user's password (leave blank to be prompted).
USER_PASSWORD='user'

# Change keyboard to french
loadkeys fr

# System timezone.
TIMEZONE='Europe/Paris'

# Partitioning with parted
parted /dev/sda mklabel gpt
parted /dev/sda mkpart ESP fat32 1MiB 1GiB
parted /dev/sda set 1 esp on
parted /dev/sda mkpart LVM 1GiB 100%

# Reload partition table
partprobe /dev/sda

# Format EFI partition
mkfs.fat -F 32 /dev/sda1
mount --mkdir /dev/sda1 /mnt/boot/efi

# Setup LVM
vgcreate vg_group /dev/sda2
lvcreate -L 4G -n SWAP vg_group 
lvcreate -L 15G -n lv_home_colleague vg_group 
lvcreate -L 5G -n lv_home_son vg_group 
lvcreate -L 5G -n lv_shared vg_group 
lvcreate -L 10G -n lv_encrypted vg_group
lvcreate -L 20G -n lv_VM vg_group
lvcreate -l 100%FREE -n lv_root vg_group 

# Encrypt the logical volume
echo "azert123" | cryptsetup luksFormat /dev/vg_group/lv_encrypted

# Format file systems
mkswap /dev/vg_group/SWAP
mkfs.ext4 /dev/vg_group/lv_home_colleague
mkfs.ext4 /dev/vg_group/lv_home_son
mkfs.ext4 /dev/vg_group/lv_shared
mkfs.ext4 /dev/vg_group/lv_VM
mkfs.ext4 /dev/vg_group/lv_root

# Mount file systems
mount --mkdir /dev/vg_group/lv_root /mnt
mount --mkdir /dev/vg_group/lv_home_colleague /mnt/home/colleague
mount --mkdir /dev/vg_group/lv_home_son /mnt/home/son
mount --mkdir /dev/vg_group/lv_shared /mnt/shared
mount --mkdir /dev/vg_group/lv_VM /mnt/vm

swapon /dev/vg_group/SWAP

pacstrap -K /mnt base linux linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into system and configure
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/GMT /etc/localtime
hwclock --systohc

sed -i 's/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr" > /etc/vconsole.conf
echo "CustomArch" > /etc/hostname
echo "root:azerty123" | chpasswd

mkinitcpio -P

# Install and configure GRUB
pacman -S grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# Exit chroot, unmount, and reboot
exit
umount -a
reboot
