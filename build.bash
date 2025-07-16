#!/bin/bash

# Script para crear una ISO personalizada de Debian Bookworm
# Requiere permisos de root para ejecutarse correctamente

# Verificar si se está ejecutando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

# Instalar dependencias necesarias
echo "Instalando dependencias necesarias..."
apt-get update
apt-get install -y xorriso isolinux wget syslinux-utils squashfs-tools

# Configuración
STYX_VERSION="0.1"
ISO_URL="https://cdimage.debian.org/cdimage/release/current/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso"
ISO_NAME="debian-12.11.0-amd64-netinst.iso"
CUSTOM_ISO_NAME="styx-firewall-${STYX_VERSION}-custom.iso"
WORK_DIR="/tmp/debian-iso-custom"
MOUNT_DIR="${WORK_DIR}/mount"
EXTRACT_DIR="${WORK_DIR}/extract"
EDIT_DIR="${WORK_DIR}/edit"

# URLs del repositorio STYX (añadido)
STYX_GPG_KEY="https://styx-firewall.github.io/styx-repo/KEY.gpg"
STYX_SOURCES_LIST="https://styx-firewall.github.io/styx-repo/styx.list"

# Paquetes para añadir (modifica según tus necesidades)
ADD_PACKAGES="linux-image-6.12.32-10-styx linux-headers-6.12.32-10-styx net-tools"
# Paquetes para quitar (modifica según tus necesidades)
REMOVE_PACKAGES="linux-image-amd64 linux-headers-amd64"



# Crear directorios de trabajo
echo "Creando directorios de trabajo..."
rm -rf "${WORK_DIR}"
mkdir -p "${MOUNT_DIR}" "${EXTRACT_DIR}" "${EDIT_DIR}"

# Descargar ISO oficial si no existe
if [ ! -f "${ISO_NAME}" ]; then
    echo "Descargando ISO oficial de Debian ${STYX_VERSION}..."
    wget "${ISO_URL}" -O "${ISO_NAME}"
else
    echo "Usando ISO existente: ${ISO_NAME}"
fi

# Montar la ISO original
echo "Montando la ISO original..."
mount -o loop "${ISO_NAME}" "${MOUNT_DIR}"

# Copiar contenido de la ISO al directorio de extracción
echo "Copiando contenido de la ISO..."
cp -r "${MOUNT_DIR}/." "${EXTRACT_DIR}/"

# Desmontar la ISO
echo "Desmontando la ISO..."
umount "${MOUNT_DIR}"

# Copiar contenido al directorio de edición
echo "Preparando sistema de archivos para modificación..."
rsync -a "${EXTRACT_DIR}/" "${EDIT_DIR}/"

# Montar el sistema de archivos squashfs
echo "Montando filesystem.squashfs..."
unsquashfs -f -d "${EDIT_DIR}/squashfs-root" "${EDIT_DIR}/install.amd/squashfs-root/filesystem.squashfs"

# Montar los directorios necesarios para chroot
echo "Montando directorios especiales para chroot..."
mount --bind /dev "${EDIT_DIR}/squashfs-root/dev"
mount -t proc proc "${EDIT_DIR}/squashfs-root/proc"
mount -t sysfs sys "${EDIT_DIR}/squashfs-root/sys"

# Configurar DNS para el entorno chroot
echo "Configurando DNS para chroot..."
cp /etc/resolv.conf "${EDIT_DIR}/squashfs-root/etc/resolv.conf"

# Modificar la instalación dentro del chroot
echo "Entrando en chroot para modificar paquetes..."
chroot "${EDIT_DIR}/squashfs-root" /bin/bash <<EOF
# Actualizar lista de paquetes
apt-get update

# Añadir repositorio STYX
echo "Añadiendo repositorio STYX..."
curl -s --compressed "${STYX_GPG_KEY}" | gpg --dearmor > /etc/apt/trusted.gpg.d/styx.gpg
curl -s --compressed -o /etc/apt/sources.list.d/styx.list "${STYX_SOURCES_LIST}"

# Quitar paquetes no deseados
if [ -n "${REMOVE_PACKAGES}" ]; then
    echo "Quitando paquetes: ${REMOVE_PACKAGES}"
    apt-get remove -y --purge ${REMOVE_PACKAGES}
    apt-get autoremove -y
fi

# Añadir paquetes nuevos
if [ -n "${ADD_PACKAGES}" ]; then
    echo "Instalando paquetes: ${ADD_PACKAGES}"
    apt-get install -y ${ADD_PACKAGES}
fi

# Actualizamos otra vez para actualizar los paquetes Styx
apt-get upgrade -y
# Limpiar caché
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

# Salir del chroot y desmontar
echo "Saliendo de chroot y desmontando directorios..."
umount "${EDIT_DIR}/squashfs-root/dev"
umount "${EDIT_DIR}/squashfs-root/proc"
umount "${EDIT_DIR}/squashfs-root/sys"

# Recrear el filesystem.squashfs
echo "Recreando filesystem.squashfs..."
rm -f "${EDIT_DIR}/install.amd/squashfs-root/filesystem.squashfs"
mksquashfs "${EDIT_DIR}/squashfs-root" "${EDIT_DIR}/install.amd/squashfs-root/filesystem.squashfs" -comp xz

# Calcular nuevos hashes MD5
echo "Calculando nuevos hashes MD5..."
cd "${EDIT_DIR}"
find -type f -print0 | xargs -0 md5sum > md5sum.txt
cd -

# Crear nueva ISO
echo "Creando nueva ISO personalizada..."
xorriso -as mkisofs \
    -r -V "Debian ${DEBIAN_VERSION} Custom" \
    -o "${CUSTOM_ISO_NAME}" \
    -J -J -joliet-long -cache-inodes \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -isohybrid-apm-hfsplus \
    "${EDIT_DIR}"

# Limpiar
echo "Limpiando directorios temporales..."
rm -rf "${WORK_DIR}"

echo "¡ISO personalizada creada con éxito!: ${CUSTOM_ISO_NAME}"
echo "Tamaño de la ISO: $(du -h ${CUSTOM_ISO_NAME} | cut -f1)"
