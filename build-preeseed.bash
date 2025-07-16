#!/bin/bash

# Configuración
STYX_VERSION="0.1"
ISO_URL="https://cdimage.debian.org/cdimage/release/current/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso"
CUSTOM_ISO_NAME="styx-netinst-${STYX_VERSION}.iso"
WORK_DIR="/tmp/netinst-custom"

# Limpieza y preparación
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1

# 1. Descargar ISO netinst
wget "$ISO_URL" -O original.iso

# 2. Extraer contenido ISO
xorriso -osirrox on -indev original.iso -extract / extracted

# 3. Preparar preseed.cfg para instalación automática
cat > extracted/preseed.cfg <<EOF
d-i netcfg/get_hostname string styx

# Paquetes a instalar
tasksel tasksel/first multiselect standard
d-i pkgsel/include string linux-image-6.12.32-10-styx linux-headers-6.12.32-10-styx net-tools
d-i pkgsel/upgrade select none

# 3.1. Instalar paquetes STYX
d-i apt-setup/local1/repository string deb https://styx-firewall.github.io/styx-repo/ bookworm main
d-i apt-setup/local1/comment string Repositorio STYX
d-i apt-setup/local1/key string https://styx-firewall.github.io/styx-repo/KEY.gpg

# 3.2. Paquetes a instalar (kernel STYX + dependencias)
d-i pkgsel/include string linux-image-6.12.32-10-styx linux-headers-6.12.32-10-styx net-tools
# Desinstalar
d-i pkgsel/remove string git git-*

# 3.3. Actualizar repositorios y paquetes DURANTE instalación
d-i preseed/late_command string \
    in-target apt-get update; \
    in-target apt-get install -y linux-image-6.12.32-10-styx linux-headers-6.12.32-10-styx; \
    in-target apt-get clean;

EOF

# 4. Modificar el menú de instalación
#sed -i 's/timeout 0/timeout 1/' extracted/isolinux/isolinux.cfg
#sed -i '/menu default/d' extracted/isolinux/txt.cfg
#sed -i '/label install/a \  menu default' extracted/isolinux/txt.cfg
#sed -i '/append / s/$/ auto=true priority=critical preseed\/file=\/cdrom\/preseed.cfg/' extracted/isolinux/txt.cfg

# 4. Modificar menú para añadir opción automática (presionar TAB para ver)
sed -i '/label install/a \
  menu label ^Instalar STYX Automatico\
  kernel /install.amd/vmlinuz\
  append auto=true priority=critical vga=788 initrd=/install.amd/initrd.gz --- quiet' extracted/isolinux/txt.cfg

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

# 6. Limpieza y resultado
mv "$CUSTOM_ISO_NAME" ~/
echo "ISO personalizada creada en ~/$CUSTOM_ISO_NAME"
du -h ~/"$CUSTOM_ISO_NAME"