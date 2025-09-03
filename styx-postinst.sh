#!/bin/bash
# v0.6
set -e  # Detiene el script si hay errores

echo "1 " >> /test.log
# Configurar repositorio STYX
curl -fsSL https://styx-firewall.github.io/styx-repo/styx-firewall-keyring.gpg | tee /usr/share/keyrings/styx-firewall-keyring.gpg >/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/styx-firewall-keyring.gpg] https://styx-firewall.github.io/styx-repo trixie main" | tee /etc/apt/sources.list.d/styx.list

# Limpiar caché de paquetes
apt-get clean

# Crear usuario 'admin' con contraseña 'admin'
if ! id admin &>/dev/null; then
    useradd -m -s /bin/bash admin
    echo "admin:admin" | chpasswd
fi

# Initial config files
cp /var/lib/styx/configs/ulogd.conf /etc/ulogd.conf
cp /var/lib/styx/configs/sshd_config /etc/ssh/sshd_config
cp /var/lib/styx/configs/logrotate.conf /etc/logrotate.conf
cp /var/lib/styx/configs/lr-ulogd2 /etc/logrotate.d/ulogd2
cp /var/lib/styx/configs/os-release /etc/os-release
#cp /var/lib/styx/configs/journald.conf /etc/systemd/journald.conf
#cp /var/lib/styx/configs/motd /etc/motd
#cp /var/lib/styx/configs/issue /etc/issue

# Update grub after modifying os-release
update-grub

# Be sure services are enabled
systemctl enable ssh
systemctl enable ulogd2
systemctl enable logrotate
systemctl enable udhcpc

# Clean
apt remove --purge -y latptop-detect
apt remove --purge -y dhcpcd-base

# Configurar tmpfs en fstab  Trixie comes with tmpfs by default
# grep -q "tmpfs /tmp tmpfs" /etc/fstab || echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab

# Instalar dependecias de STYX
#apt-get install -y --no-install-recommends pip python3.11-venv
# Firewall utilities
#apt-get install -y nftables net-tools
# Network Interface utilities
#apt-get install -y vlan ifenslave bridge-utils
# Logging
#apt-get install -y ulogd2 ulogd2-json ulogd2-pcap
# PPoE utilities
#apt install -y pppoe pppoeconf
# BPF tools
#apt-get install  bpfcc-tools libbpfcc libbpfcc-dev
# User PAM
#apt-get install -y python3-pam

