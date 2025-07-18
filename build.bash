#!/bin/bash
# version 0.2
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

# Configuración
STYX_VERSION="0.1"
ISO_NAME="debian-12.11.0-amd64-netinst.iso"
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/${ISO_NAME}"

CUSTOM_ISO_NAME="styx-firewall-${STYX_VERSION}.iso"
WORK_DIR="/tmp/netinst-custom"
STYX_GPG_KEY="https://styx-firewall.github.io/styx-repo/styx-firewall-keyring.gpg"
STYX_SOURCES_LIST="https://styx-firewall.github.io/styx-repo/styx.list"

# Instalar dependencias necesarias
echo "Instalando dependencias necesarias..."
apt-get update
apt-get install -y xorriso isolinux wget syslinux-utils

# Limpieza y preparación
rm -rf "$WORK_DIR/extracted"
#rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp styx-postinst.sh "$WORK_DIR/"
cd "$WORK_DIR" || exit 1

# 1. Descargar ISO netinst
if [ ! -f "$ISO_NAME" ]; then
  wget -c "$ISO_URL" -O "$ISO_NAME"
fi

# 2. Extraer contenido ISO
xorriso -osirrox on -indev "$ISO_NAME" -extract / extracted

# PostInstall Script
mkdir -p extracted/extra/
cp ./styx-postinst.sh extracted/extra/
chmod +x extracted/extra/styx-postinst.sh

# 3. Preparar preseed.cfg para instalación automática
cat > extracted/preseed.cfg <<EOF

# Early commands
# Allow admin user to be created
d-i preseed/early_command string \
    mkdir -p /target/etc && \
    sed -i '/^admin$/d' /target/etc/adduser.conf;

# Configuración de red
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string styx
d-i netcfg/get_domain string styx.local

# Particionamiento (ajustar según necesidades)
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# Configuración de usuario
#d-i passwd/root-login boolean false
#d-i passwd/make-user boolean true  
d-i passwd/allow-badname boolean true
d-i user-setup/allow-password-weak boolean true  
d-i passwd/user-fullname string admin
d-i passwd/username string admin
d-i passwd/user-password password admin
d-i passwd/user-password-again password admin
d-i user-setup/encrypt-home boolean false

# Grupos de usuario
#d-i passwd/user-default-groups string sudo

# Configuracion discos
d-i partman-auto/disk string /dev/sda
#d-i partman-auto/method string lvm

# Configuracion Particionado
#d-i partman-auto/choose_recipe select server

# Instala GRUB automáticamente en /dev/sda
d-i grub-installer/bootdev string /dev/sda
d-i grub-installer/only_debian boolean true
d-i grub-installer/confirm boolean true
d-i grub-installer/with_other_os boolean false

# Mirror 
d-i mirror/country string automatic
d-i mirror/http/proxy string
d-i mirror/protocol string http
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian

d-i apt-setup/security_host string security.debian.org
d-i apt-setup/security_path string /debian-security

# Paquetes
## No instalar paquetes recomendados
tasksel tasksel/first multiselect
d-i pkgsel/install-recommends boolean false

# No actualizar paquetes
d-i pkgsel/update-policy select none
d-i pkgsel/upgrade select none

# Custom Paquetes
d-i pkgsel/include string net-tools curl openssh-server openssh-client

# Excluir paquetes específicos si es necesario
# isc-dhcp-client y isc-dhcp-server cuando se reemplace por kea
d-i pkgsel/exclude string openssh-ftp-server

# Misc
## Survey false
d-i popularity-contest/participate boolean false

# Comandos post-instalación
#d-i preseed/late_command string \
#    in-target sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/styx.gpg] https://styx-firewall.github.io/styx-repo/ bookworm main" > /etc/apt/sources.list.d/styx.list'; \
#    in-target wget -O /usr/share/keyrings/styx.gpg https://styx-firewall.github.io/styx-repo/styx-firewall-keyring.gpg; \
#    in-target apt-get update; \
#    in-target apt-get install -y linux-image-6.12.32-10-styx linux-headers-6.12.32-10-styx; \
#    in-target apt-get purge -y linux-image-amd64 linux-headers-amd64; \
#    in-target systemctl enable ssh; \
#    in-target update-grub; \
#    in-target apt-get clean; \
#    in-target systemctl enable tmp.mount && \
#    in-target systemctl mask tmp-fs.target    

# late_command
d-i preseed/late_command string \
    in-target cp /cdrom/extra/styx-postinst.sh /tmp/ ; \
    in-target chmod +x /tmp/styx-postinst.sh ; \
    in-target /tmp/styx-postinst.sh ; \
    in-target rm /tmp/styx-postinst.sh

#in-target echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /target/etc/fstab ;

# Reboot once finished
d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/poweroff boolean true
EOF

# Modificar el menú para añadir opción automática
#cat > extracted/isolinux/txt.cfg <<EOF
#default auto-install-styx
#timeout 50
#prompt 0

cat > extracted/isolinux/isolinux.cfg <<EOF
default auto-install-styx
timeout 5
prompt 0

label auto-install-styx
  menu label ^Instalacion automatica de STYX
  menu default
  kernel /install.amd/vmlinuz
  append auto=true priority=high vga=788 initrd=/install.amd/initrd.gz preseed/file=/cdrom/preseed.cfg --- quiet
EOF

# 5. Modificar el menú gráfico (UEFI)
cat > extracted/boot/grub/grub.cfg <<EOF
set timeout=5
menuentry "Instalacion automatica de STYX" {
    linux /install.amd/vmlinuz auto=true priority=high preseed/file=/cdrom/preseed.cfg --- quiet
    initrd /install.amd/initrd.gz
}
EOF


# Eliminar el menú txt.cfg original
rm extracted/isolinux/txt.cfg

# Cleanup iso 
rm -rf extracted/install.amd/gtk
rm -rf extracted/pool/extra/* 
rm -rf extracted/pool/main/g/gcc-*
rm -rf extracted/pool/main/g/gtk*
rm -rf extracted/pool/main/e/espeek*
rm -rf extracted/pool/main/f/fonts-noto*
rm -rf extracted/pool/main/i/iptables
rm -rf extracted/non-free-firmware/n/nvidia-graphics-drivers-tesla-*
rm -rf extracted/pool/main/x/xserver-xorg*
rm -rf extracted/pool/main/x/xfsprogs
rm -rf extracted/install.amd/doc
rm -rf extracted/doc


# 5. Reconstruir la ISO
xorriso -as mkisofs \
  -r -V "STYX NetInst" \
  -o "$CUSTOM_ISO_NAME" \
  -J -joliet-long \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  extracted



isohybrid "$CUSTOM_ISO_NAME"
echo "ISO creada en $WORK_DIR/$CUSTOM_ISO_NAME"
mv $WORK_DIR/$CUSTOM_ISO_NAME /var/www/html/
echo "ISO movida a /var/www/html/"
