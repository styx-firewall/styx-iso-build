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

# Default services
systemctl disable apt-daily-upgrade.service
systemctl disable dpkg-db-backup.service
systemctl disable systemd-battery-check.service
systemctl disable systemd-hybrid-sleep.service
systemctl disable systemd-quotacheck-root.service
systemctl disable systemd-suspend-then-hibernate.service
systemctl disable systemd-suspend.service
systemctl disable display-manager.service
systemctl disable plymouth-*.service
#systemctl disable apparmor.service
#systemctl disable apt-daily.service
#systemctl disable e2scrub_all.service
#systemctl disable e2scrub_reap.service
#systemctl disable fstrim.service
#systemctl disable getty-static.service
#systemctl disable grub-common.service
#systemctl disable initrd-cleanup.service
#systemctl disable initrd-parse-etc.service
#systemctl disable initrd-switch-root.service
#systemctl disable initrd-udevadm-cleanup-db.service
#systemctl disable modprobe@*.service
#systemctl disable rc-local.service
#systemctl disable rescue.service
#systemctl disable systemd-ask-password-console.service
#systemctl disable systemd-ask-password-wall.service
#systemctl disable systemd-bsod.service
#systemctl disable systemd-confext.service
#systemctl disable systemd-firstboot.service
#systemctl disable systemd-fsck-root.service
#systemctl disable systemd-hibernate-clear.service
#systemctl disable systemd-hibernate-resume.service
#systemctl disable systemd-hibernate.service
#systemctl disable systemd-hostnamed.service
#systemctl disable systemd-hwdb-update.service
#systemctl disable systemd-initctl.service
#systemctl disable systemd-journal-catalog-update.service
#systemctl disable systemd-journald-sync@.service
#systemctl disable systemd-networkd-persistent-storage.service
#systemctl disable systemd-pcrmachine.service
#systemctl disable systemd-pcrphase-initrd.service
#systemctl disable systemd-pcrphase-sysinit.service
#systemctl disable systemd-pcrphase.service
#systemctl disable systemd-poweroff.service
#systemctl disable systemd-soft-reboot.service
#systemctl disable systemd-sysext.service
#systemctl disable systemd-tpm2-setup-early.service
#systemctl disable systemd-tpm2-setup.service
#systemctl disable systemd-udev-settle.service
#systemctl disable systemd-vconsole-setup.service
#systemctl disable NetworkManager.service
#systemctl disable connman.service
#systemctl disable kbd.service
#systemctl disable syslog.service
#systemctl disable ifupdown-pre.service
#systemctl disablenetworking.service

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

