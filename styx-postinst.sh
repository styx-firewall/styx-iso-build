#!/bin/bash
# v0.6
set -e  # Detiene el script si hay errores

echo "1 " >> /test.log
# Configurar repositorio STYX
curl -fsSL https://styx-firewall.github.io/styx-repo/styx-firewall-keyring.gpg | tee /usr/share/keyrings/styx-firewall-keyring.gpg >/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/styx-firewall-keyring.gpg] https://styx-firewall.github.io/styx-repo trixe main" | tee /etc/apt/sources.list.d/styx.list

# Limpiar caché de paquetes
apt-get clean

# Crear usuario 'admin' con contraseña 'admin'
if ! id admin &>/dev/null; then
    useradd -m -s /bin/bash admin
    echo "admin:admin" | chpasswd
fi
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

