#!/bin/bash
set -e

# === Configuration ===
STYX_VERSION="0.8"
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
    "linux-headers-6.12.48-14-styx_14_amd64.deb"
    "linux-image-6.12.48-14-styx_14_amd64.deb"
    "styx-conf-0.1-9.deb"
    "styx-gateway-0.1-1.deb"
    "styx-ui-0.1-1.deb"
    "styx-firewall-0.1-1.deb"
)

# Construct full URLs for DEB packages
DEB_PACKAGES=()
for pkg_file in "${DEB_PACKAGE_FILES[@]}"; do
    DEB_PACKAGES+=("${DEB_BASE_URL}${pkg_file}")
done

# === Preparation ===
mkdir -p "$WORKDIR"
# Clean previous
rm -rf "$WORKDIR"/iso
#rm -f "$CUSTOM_PACKAGES_DIR"/*
mkdir -p "$WORKDIR/mnt"
mount -o loop "$BASE_ISO" "$WORKDIR/mnt"

echo "[*] Copying contents of the base ISO..."
mkdir -p "$WORKDIR/iso"
rsync -a --exclude=TRANS.TBL "$WORKDIR/mnt/" "$WORKDIR/iso/"
umount "$WORKDIR/mnt"

# Post-Installation Script
cp styx-postinst.sh "$WORKDIR/iso"

# === Copy preseed.cfg ===
if [ -f "$PRESEED_FILE" ]; then
    echo "[*] Copying preseed.cfg..."
    cp "$PRESEED_FILE" "$WORKDIR/iso/preseed.cfg"
else
    echo "[!] preseed.cfg file not found, aborting."
    exit 1
fi

# === Download DEB packages ===
echo "[*] Downloading DEB packages ..."

mkdir -p "$CUSTOM_PACKAGES_DIR"
# To avoid set -e error on timeout
if ! read -t 5 -p "Clean the custom packages directory ($CUSTOM_PACKAGES_DIR)? [y/N]: " clean_custom_dir; then
    clean_custom_dir="n"
fi
clean_custom_dir=${clean_custom_dir:-N}
if [[ "$clean_custom_dir" =~ ^[Yy]$ ]]; then
    echo "Cleaning $CUSTOM_PACKAGES_DIR ..."
    rm -f "$CUSTOM_PACKAGES_DIR"/*
fi


# Download and verify each .deb file
download_failed=0
for url in "${DEB_PACKAGES[@]}"; do
    filename=$(basename "$url")
    if [ ! -f "$CUSTOM_PACKAGES_DIR/$filename" ]; then
        echo "[*] Downloading $filename ..."
        if ! wget -O "$CUSTOM_PACKAGES_DIR/$filename" "$url"; then
            echo "[!] Error downloading $filename"
            download_failed=1
        fi
    else
        echo "  - $filename already exists, skipping download."
    fi
    # Verify that the file exists and is not empty
    if [ ! -s "$CUSTOM_PACKAGES_DIR/$filename" ]; then
        echo "[!] File $filename does not exist or is empty after download."
        download_failed=1
    fi
done

# If any download failed, abort the script
if [ "$download_failed" -ne 0 ]; then
    echo "[!] One or more .deb package downloads failed. Aborting."
    exit 1
fi

# === Add custom packages (.deb) ===
if compgen -G "$CUSTOM_PACKAGES_DIR/*.deb" > /dev/null; then
    echo "[*] Adding custom packages..."
    mkdir -p "$WORKDIR/iso/pool/extras"
    cp "$CUSTOM_PACKAGES_DIR"/*.deb "$WORKDIR/iso/pool/extras/"

    echo "[*] Generating Packages.gz..."
    mkdir -p "$WORKDIR/iso/dists/stable/extras/binary-amd64"
    cd "$WORKDIR/iso"
    dpkg-scanpackages pool/extras /dev/null | gzip -9 > dists/stable/extras/binary-amd64/Packages.gz
    cd - > /dev/null
else
    echo "[!] No custom .deb packages found in $CUSTOM_PACKAGES_DIR"
fi

# === Modify boot menu (isolinux) ===
TXT_CFG="$WORKDIR/iso/isolinux/txt.cfg"
if grep -q "label install" "$TXT_CFG"; then
    echo "[*] Modifying boot menu to use preseed.cfg..."
    sed -i '/^label install/,/^$/s@^\( *append \).*@\1auto=true priority=critical preseed/file=/cdrom/preseed.cfg initrd=/install.amd/initrd.gz ---@' "$TXT_CFG"
else
    echo "[!] 'label install' entry not found in txt.cfg. Please modify it manually."
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

# 5. Modify graphical menu (UEFI)
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

# Cleaning ISO
rm -rf "$WORKDIR/iso/doc"
rm -rf "$WORKDIR/pool/main/f/fonts-noto*"
rm -rf "$WORKDIR/non-free-firmware/n/nvidia-graphics-drivers-tesla-*"
rm -rf "$WORKDIR/pool/main/x/xserver-xorg*"
rm -rf "$WORKDIR/pool/main/l/linux-signed-amd64/linux-*"

# === Create new hybrid ISO ===
echo "[*] Creating new final ISO..."

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

echo "[+] ISO generated: $NEW_ISO"
mv "$NEW_ISO" /var/www/html/
# http://192.168.2.154/styx-firewall-0.8.iso
