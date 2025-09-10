#!/bin/bash
# v0.8
set -e

# === Configuración ===
STYX_VERSION="0.5"
BASE_ISO="debian-13.0.0-amd64-netinst.iso"
CUSTOM_PACKAGES_DIR="./packages"
WORKDIR="./iso_build"
NEW_ISO="styx-firewall-${STYX_VERSION}.iso"
PRESEED_FILE="./preseed.cfg"

# Base URL for DEB packages
DEB_BASE_URL="https://github.com/styx-firewall/styx-repo/raw/main/pool/main/"

# List of DEB package filenames
DEB_PACKAGE_FILES=(
    "linux-image-styx.deb"
    "linux-headers-styx.deb"
    "linux-headers-6.12.42-13-styx_13_amd64.deb"
    "linux-image-6.12.42-13-styx_13_amd64.deb"
    "styx-conf-0.1-5.deb"
)

# Construct full URLs for DEB packages
DEB_PACKAGES=()
for pkg_file in "${DEB_PACKAGE_FILES[@]}"; do
    DEB_PACKAGES+=("${DEB_BASE_URL}${pkg_file}")
done

# === Preparación ===
mkdir -p "$WORKDIR"
# Limpiar previo
rm -rf "$WORKDIR"/iso
#rm -f "$CUSTOM_PACKAGES_DIR"/*
mkdir -p "$WORKDIR/mnt"
mount -o loop "$BASE_ISO" "$WORKDIR/mnt"

echo "[*] Copiando contenido de la ISO base..."
mkdir -p "$WORKDIR/iso"
rsync -a --exclude=TRANS.TBL "$WORKDIR/mnt/" "$WORKDIR/iso/"
umount "$WORKDIR/mnt"

# Script Post-Instalación
cp styx-postinst.sh "$WORKDIR/iso"

# === Copiar preseed.cfg ===
if [ -f "$PRESEED_FILE" ]; then
    echo "[*] Copiando preseed.cfg..."
    cp "$PRESEED_FILE" "$WORKDIR/iso/preseed.cfg"
else
    echo "[!] Archivo preseed.cfg no encontrado, abortando."
    exit 1
fi

# === Descargar paquetes DEB ===
echo "[*] Descargando paquetes DEB ..."
mkdir -p "$CUSTOM_PACKAGES_DIR"
for url in "${DEB_PACKAGES[@]}"; do
    filename=$(basename "$url")
    if [ ! -f "$CUSTOM_PACKAGES_DIR/$filename" ]; then
        wget -O "$CUSTOM_PACKAGES_DIR/$filename" "$url"
    else
        echo "  - $filename ya existe, omitiendo descarga."
    fi
done

# === Agregar paquetes personalizados (.deb) ===
if compgen -G "$CUSTOM_PACKAGES_DIR/*.deb" > /dev/null; then
    echo "[*] Agregando paquetes personalizados..."
    mkdir -p "$WORKDIR/iso/pool/extras"
    cp "$CUSTOM_PACKAGES_DIR"/*.deb "$WORKDIR/iso/pool/extras/"

    echo "[*] Generando Packages.gz..."
    mkdir -p "$WORKDIR/iso/dists/stable/extras/binary-amd64"
    cd "$WORKDIR/iso"
    dpkg-scanpackages pool/extras /dev/null | gzip -9 > dists/stable/extras/binary-amd64/Packages.gz
    cd - > /dev/null
else
    echo "[!] No se encontraron .deb personalizados en $CUSTOM_PACKAGES_DIR"
fi

# === Modificar menú de arranque (isolinux) ===
TXT_CFG="$WORKDIR/iso/isolinux/txt.cfg"
if grep -q "label install" "$TXT_CFG"; then
    echo "[*] Modificando menú de arranque para usar preseed.cfg..."
    sed -i '/^label install/,/^$/s@^\( *append \).*@\1auto=true priority=critical preseed/file=/cdrom/preseed.cfg initrd=/install.amd/initrd.gz ---@' "$TXT_CFG"
else
    echo "[!] No se encontró entrada 'label install' en txt.cfg. Modifícalo manualmente."
fi

cat > $WORKDIR/iso/isolinux/isolinux.cfg <<EOF
default auto-install-styx
timeout 5
prompt 0

label auto-install-styx
  menu label ^Auto Install STYX (Isolinux)
  menu default
  kernel /install.amd/vmlinuz
  append auto=true priority=high vga=788 initrd=/install.amd/initrd.gz preseed/file=/cdrom/preseed.cfg --- quiet
EOF

# 5. Modificar el menú gráfico (UEFI)
cat > $WORKDIR/iso/boot/grub/grub.cfg <<EOF
if [ x$feature_default_font_path = xy ] ; then
   font=unicode
else
   font=$prefix/font.pf2
fi

if loadfont $font ; then
  set gfxmode=800x600
  set gfxpayload=keep
  insmod efi_gop
  insmod efi_uga
  insmod video_bochs
  insmod video_cirrus
  insmod gfxterm
  insmod png
  terminal_output gfxterm
fi

if background_image /isolinux/splash.png; then
  set color_normal=light-gray/black
  set color_highlight=white/black
elif background_image /splash.png; then
  set color_normal=light-gray/black
  set color_highlight=white/black
else
  set menu_color_normal=cyan/blue
  set menu_color_highlight=white/blue
fi

insmod play
play 960 440 1 0 4 440 1
set theme=/boot/grub/theme/1

set timeout=5
menuentry --hotkey=g 'Styx Graphical Install' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 auto=true priority=high preseed/file=/cdrom/preseed.cfg --- quiet
    initrd   /install.amd/gtk/initrd.gz
}
menuentry --hotkey=g 'Styx Graphical Install (Dark Theme)' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 theme=dark auto=true priority=high preseed/file=/cdrom/preseed.cfg --- quiet
    initrd   /install.amd/gtk/initrd.gz
}
menuentry "Styx Install" {
    linux /install.amd/vmlinuz auto=true priority=high preseed/file=/cdrom/preseed.cfg --- quiet
    initrd /install.amd/initrd.gz
}
menuentry --hotkey=r 'Rescue mode' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 rescue/enable=true --- quiet
    initrd   /install.amd/initrd.gz
}

EOF

# Limpiando  ISO
rm -rf "$WORKDIR/iso/doc"
rm -rf "$WORKDIR/pool/main/f/fonts-noto*"
rm -rf "$WORKDIR/non-free-firmware/n/nvidia-graphics-drivers-tesla-*"
rm -rf "$WORKDIR/pool/main/x/xserver-xorg*"
rm -rf "$WORKDIR/pool/main/l/linux-signed-amd64/linux-*"

# === Crear nueva ISO híbrida ===
echo "[*] Creando nueva ISO final..."

xorriso -as mkisofs \
  -r -V "STYX NetInst" \
  -o "$NEW_ISO" \
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
  "$WORKDIR/iso"

echo "[+] ISO generada: $NEW_ISO"
mv "$NEW_ISO" /var/www/html/
# http://192.168.2.154/styx-firewall-0.5.iso