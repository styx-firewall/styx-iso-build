#!/bin/bash
set -e  # Detiene el script si hay errores

# Configurar repositorio STYX
curl -fsSL https://styx-firewall.github.io/styx-repo/styx-firewall-keyring.gpg | tee /usr/share/keyrings/styx-firewall-keyring.gpg >/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/styx-firewall-keyring.gpg] https://styx-firewall.github.io/styx-repo bookworm main" | tee /etc/apt/sources.list.d/styx.list
# Instalar kernel y paquetes
apt-get update
apt-get install -y --no-install-recommends \
    linux-image-6.12.32-10-styx \
    linux-headers-6.12.32-10-styx

# Limpieza
apt-get purge -y linux-image-amd64 linux-headers-amd64
apt upgrade -y
systemctl enable ssh
update-grub
apt-get clean

# Crear usuario 'admin' con contraseña 'admin'
useradd -m -s /bin/bash admin
echo "admin:admin" | chpasswd

# Configurar tmpfs en fstab
grep -q "tmpfs /tmp tmpfs" /etc/fstab || echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab

reboot