#!/bin/bash
# v0.6
set -e

# === Configuración ===
STYX_VERSION="0.1"
BASE_ISO="debian-12.11.0-amd64-netinst.iso"
CUSTOM_PACKAGES_DIR="./packages"               # Incluye tu kernel .deb
WORKDIR="./iso_build"
NEW_ISO="styx-firewall-${STYX_VERSION}.iso"
PRESEED_FILE="./preseed.cfg"

DEB_PACKAGES=(
    "https://styx-firewall.github.io/styx-repo/pool/main/linux-headers-6.12.32-10-styx_10-styx_amd64.deb"
    "https://styx-firewall.github.io/styx-repo/pool/main/linux-image-6.12.32-10-styx_10-styx_amd64.deb"
)

# === Preparación ===
mkdir -p "$WORKDIR"
rm -rf "$WORKDIR"/iso
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
  menu label ^Instalacion automatica de STYX
  menu default
  kernel /install.amd/vmlinuz
  append auto=true priority=high vga=788 initrd=/install.amd/initrd.gz preseed/file=/cdrom/preseed.cfg --- quiet
EOF

# 5. Modificar el menú gráfico (UEFI)
cat > $WORKDIR/iso/boot/grub/grub.cfg <<EOF
set timeout=5
menuentry "Instalacion automatica de STYX" {
    linux /install.amd/vmlinuz auto=true priority=high preseed/file=/cdrom/preseed.cfg --- quiet
    initrd /install.amd/initrd.gz
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
# http://192.168.2.154/styx-firewall-0.1.iso