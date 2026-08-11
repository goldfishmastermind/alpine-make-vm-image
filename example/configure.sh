#!/bin/sh

_step_counter=0
step() {
	_step_counter=$(( _step_counter + 1 ))
	printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

uname -a

step 'Set up timezone'
setup-timezone -z Europe/Prague

step 'Set up networking'
cat > /etc/network/interfaces <<-EOF
	iface lo inet loopback
	iface eth0 inet dhcp
EOF
ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0

step 'Adjust rc.conf'
sed -Ei \
	-e 's/^[# ](rc_depend_strict)=.*/\1=NO/' \
	-e 's/^[# ](rc_logger)=.*/\1=YES/' \
	-e 's/^[# ](unicode)=.*/\1=YES/' \
	/etc/rc.conf

step 'Enable services'
rc-update add acpid default
rc-update add chronyd default
rc-update add crond default
rc-update add net.eth0 default
rc-update add net.lo boot
rc-update add termencoding boot

# ========== UEFI BOOTLOADER FOR ARM64 ==========
if [ "$(uname -m)" = "aarch64" ]; then
    step 'Install GRUB for UEFI (aarch64)'

    # Install GRUB and efibootmgr (efibootmgr not strictly needed, but safe)
    apk add grub-efi efibootmgr

    # Mount the ESP (partition 1)
    mkdir -p /boot/efi
    mount /dev/vda1 /boot/efi

    # Install GRUB to the ESP (no NVRAM writes, rely on UEFI firmware)
    grub-install --target=arm64-efi \
                 --efi-directory=/boot/efi \
                 --bootloader-id=Alpine \
                 --no-nvram

    # Create minimal grub.cfg (adjust kernel/initrd names if needed)
    mkdir -p /boot/efi/EFI/Alpine
    cat > /boot/efi/EFI/Alpine/grub.cfg <<EOF
set root=(hd0,gpt2)
linux /boot/vmlinuz-lts root=/dev/vda2 modules=ext4 console=ttyAMA0
initrd /boot/initramfs-lts
EOF

    # Unmount ESP
    umount /boot/efi
fi

step 'List /usr/local/bin'
ls -la /usr/local/bin
