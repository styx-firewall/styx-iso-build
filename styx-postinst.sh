#!/bin/bash
# v0.5
set -e  # Detiene el script si hay errores

echo "1 " >> /test.log
# Configurar repositorio STYX
curl -fsSL https://styx-firewall.github.io/styx-repo/styx-firewall-keyring.gpg | tee /usr/share/keyrings/styx-firewall-keyring.gpg >/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/styx-firewall-keyring.gpg] https://styx-firewall.github.io/styx-repo bookworm main" | tee /etc/apt/sources.list.d/styx.list

echo "2 " >> /test.log

# Habilitar servicios
#systemctl enable ssh
# Limpiar caché de paquetes
apt-get clean

echo "5 " >> /test.log
# Crear usuario 'admin' con contraseña 'admin'
if ! id admin &>/dev/null; then
    useradd -m -s /bin/bash admin
    echo "admin:admin" | chpasswd
fi
echo "6 " >> /test.log
# Configurar tmpfs en fstab
grep -q "tmpfs /tmp tmpfs" /etc/fstab || echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab

# Instalar dependecias de STYX
#apt-get install -y --no-install-recommends pip python3.11-venv
# Firewall utilities
#echo "7 " >> /test.log
#apt-get install -y nftables net-tools
# Network Interface utilities
#echo "8 " >> /test.log
#apt-get install -y vlan ifenslave bridge-utils
# Logging
#echo "9 " >> /test.log
#apt-get install -y ulogd2 ulogd2-json ulogd2-pcap
# PPoE utilities
#echo "10 " >> /test.log
#apt install -y pppoe pppoeconf
# BPF tools
#apt-get install  bpfcc-tools libbpfcc libbpfcc-dev
# User PAM
#echo "11 " >> /test.log
#apt-get install -y python3-pam
#echo "12 " >> /test.log
