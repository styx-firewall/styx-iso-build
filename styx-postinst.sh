#!/bin/bash
# v0.14

set +e  # Continue on error (do not halt)

echo "Running post-installation script..."
export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Capture access_token from kernel cmdline and clean any trace
# ---------------------------------------------------------------------------
ACCESS_TOKEN=$(grep -oP 'access_token=\K\S+' /proc/cmdline 2>/dev/null || echo "")
if [ -n "$ACCESS_TOKEN" ]; then
    # Basic UUID validation: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    if echo "$ACCESS_TOKEN" | grep -qiP '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
        echo "Access token detected from kernel cmdline (valid UUID)"
    else
        echo "[!] access_token provided but is not a valid UUID format, ignoring"
        ACCESS_TOKEN=""
    fi
else
    echo "No access_token found in kernel cmdline"
fi

# ---------------------------------------------------------------------------
# Capture network configuration from the installer for first boot seed
# ---------------------------------------------------------------------------
echo "Capturing network configuration..."
mkdir -p /etc/styx
chmod 700 /etc/styx

# Get the interface with the default route
IFACE=$(ip -o route show default | awk '{print $5}' | head -1)

if [ -n "$IFACE" ]; then
    # IP in CIDR notation (e.g., 192.168.1.100/24)
    IP_CIDR=$(ip -o -f inet addr show "$IFACE" | awk '{print $4}' | head -1)
    # Gateway
    GATEWAY=$(ip -o route show default | awk '{print $3}' | head -1)
    # MAC address of the interface
    MAC_ADDR=$(cat /sys/class/net/"$IFACE"/address 2>/dev/null)

    if [ -n "$IP_CIDR" ] && [ -n "$GATEWAY" ]; then
        # Capture nameservers from resolv.conf (may have multiple)
        NAMESERVERS=()
        while IFS= read -r line; do
            NAMESERVERS+=("$line")
        done < <(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}')

        # Capture domain/search from resolv.conf (prefer 'domain' over 'search')
        DOMAIN=$(grep -E '^(domain|search) ' /etc/resolv.conf | head -1 | awk '{print $2}')

        # Build nameservers JSON array
        NS_JSON="[]"
        if [ ${#NAMESERVERS[@]} -gt 0 ]; then
            NS_JSON="[\"${NAMESERVERS[0]}\""
            for ((i=1; i<${#NAMESERVERS[@]}; i++)); do
                NS_JSON+=",\"${NAMESERVERS[$i]}\""
            done
            NS_JSON+="]"
        fi

        # Build JSON with network + optional access_token
        NL=$'\n'
        if [ -n "$ACCESS_TOKEN" ]; then
            TOKEN_LINE=",${NL}  \"access_token\": \"${ACCESS_TOKEN}\""
        else
            TOKEN_LINE=""
        fi

        cat > /etc/styx/first_boot_seed.json <<EOF
{
  "network": {
    "address": "${IP_CIDR}",
    "gateway": "${GATEWAY}",
    "interface": "${IFACE}",
    "mac": "${MAC_ADDR}",
    "nameservers": ${NS_JSON},
    "domain": "${DOMAIN}"
  }${TOKEN_LINE}
}
EOF
        chmod 600 /etc/styx/first_boot_seed.json
        echo "  -> Saved: IP=${IP_CIDR}, Gateway=${GATEWAY}, MAC=${MAC_ADDR} (interface ${IFACE})"
        if [ -n "$ACCESS_TOKEN" ]; then
            echo "  -> Access token saved in first_boot_seed.json"
        fi
    else
        echo "  -> Warning: Could not determine IP or gateway for interface ${IFACE}"
    fi
else
    echo "  -> Warning: No default route found, network config not saved"
fi

# If no network config was saved but we have a token, save it anyway
if [ ! -f /etc/styx/first_boot_seed.json ] && [ -n "$ACCESS_TOKEN" ]; then
    cat > /etc/styx/first_boot_seed.json <<EOF
{
  "access_token": "${ACCESS_TOKEN}"
}
EOF
    chmod 600 /etc/styx/first_boot_seed.json
    echo "  -> Access token saved (no network config available)"
fi

# Configure STYX repository
curl -fsSL https://styx-firewall.github.io/styx-repo/styx-firewall-keyring.gpg | tee /usr/share/keyrings/styx-firewall-keyring.gpg >/dev/null
chmod 644 /usr/share/keyrings/styx-firewall-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/styx-firewall-keyring.gpg] https://styx-firewall.github.io/styx-repo trixie main" | tee /etc/apt/sources.list.d/styx.list
chmod 644 /etc/apt/sources.list.d/styx.list

# Clean package cache
apt-get clean

# Create user 'admin'
if ! id admin &>/dev/null; then
    useradd -m -s /bin/bash admin
    # If a valid access_token was provided, use its first block (8 hex chars) as password
    if [ -n "$ACCESS_TOKEN" ]; then
        ADMIN_PASS="${ACCESS_TOKEN%%-*}"
        echo "  -> Using first block of access_token as admin password"
    else
        ADMIN_PASS="admin"
    fi
    echo "admin:${ADMIN_PASS}" | chpasswd
    usermod -aG sudo admin
fi

apt-get update
# Ensure styx-conf is installed
apt-get install -y styx-conf

# Copy custom initial config files (copy only if source exists)
CFG_DIR=/var/lib/styx/configs

# Ensure common destination directories exist
mkdir -p /etc/ssh /etc/lighttpd /etc/lighttpd/conf-available /etc/logrotate.d

copy_if_exists() {
  src="$1"
  dst="$2"
  if [ -e "$src" ]; then
    echo "Copying $src -> $dst"
    cp "$src" "$dst"
  else
    echo "Warning: $src not found, skipping copy to $dst"
  fi
}

# Logrotate configs
copy_if_exists "$CFG_DIR/lr-ulogd2" /etc/logrotate.d/ulogd2
copy_if_exists "$CFG_DIR/lr-chrony" /etc/logrotate.d/chrony
copy_if_exists "$CFG_DIR/lr-wtmp" /etc/logrotate.d/wtmp
copy_if_exists "$CFG_DIR/lr-wtmpdb" /etc/logrotate.d/wtmpdb
copy_if_exists "$CFG_DIR/lr-styx" /etc/logrotate.d/styx
copy_if_exists "$CFG_DIR/lr-apt" /etc/logrotate.d/apt
chmod 644 /etc/logrotate.d/*

# Others
copy_if_exists "$CFG_DIR/ulogd.conf" /etc/ulogd.conf
chmod 640 /etc/ulogd.conf
copy_if_exists "$CFG_DIR/sshd_config" /etc/ssh/sshd_config
chmod 600 /etc/ssh/sshd_config
copy_if_exists "$CFG_DIR/logrotate.conf" /etc/logrotate.conf
chmod 644 /etc/logrotate.conf
copy_if_exists "$CFG_DIR/os-release" /etc/os-release
chmod 644 /etc/os-release
# copy_if_exists "$CFG_DIR/journald.conf" /etc/systemd/journald.conf
copy_if_exists "$CFG_DIR/motd" /etc/motd
chmod 644 /etc/motd
copy_if_exists "$CFG_DIR/issue" /etc/issue
chmod 644 /etc/issue
copy_if_exists "$CFG_DIR/lighttpd.conf" /etc/lighttpd/lighttpd.conf
chmod 644 /etc/lighttpd/lighttpd.conf
copy_if_exists "$CFG_DIR/lighttpd-ssl.conf" /etc/lighttpd/conf-available/10-ssl.conf
chmod 644 /etc/lighttpd/conf-available/10-ssl.conf
copy_if_exists "$CFG_DIR/rsyslog.conf" /etc/rsyslog.conf
chmod 644 /etc/rsyslog.conf
copy_if_exists "$CFG_DIR/udhcpc.conf" /etc/udhcpc/default.script
chmod 644 /etc/udhcpc/default.script
copy_if_exists "$CFG_DIR/igmpproxy.service" /etc/systemd/system/igmpproxy.service
chmod 644 /etc/systemd/system/igmpproxy.service

mkdir -p /etc/styx
chmod 700 /etc/styx
copy_if_exists "$CFG_DIR/startup-certs.json" /etc/styx/startup-certs.json
chmod 600 /etc/styx/startup-certs.json

mkdir -p /etc/systemd/system/tmp.mount.d
copy_if_exists "$CFG_DIR/tmp.conf" /etc/systemd/system/tmp.mount.d/override.conf
chmod 644 /etc/systemd/system/tmp.mount.d/override.conf

# Be sure services are enabled
systemctl enable ssh
systemctl enable ulogd2
systemctl enable logrotate
# not systemd file
# systemctl enable udhcpc ;
systemctl enable lighttpd
systemctl enable styx-gateway

# Enable tmpfs for /tmp
systemctl unmask tmp.mount 2>/dev/null
systemctl enable tmp.mount

# Generate self-signed SSL cert for lighttpd
IPS=$(hostname -I | awk '{for(i=1;i<=NF;i++) printf "IP:"$i","}' | sed 's/,$//')
mkdir -p /etc/ssl/local-private
mkdir -p /etc/ssl/local-certs
chmod 700 /etc/ssl/local-private
chmod 755 /etc/ssl/local-certs

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout /etc/ssl/local-private/https-privkey.pem  -out /etc/ssl/local-certs/https-cert.pem  \
  -subj "/C=XX/ST=Autogenerated/L=Autogenerated/O=Styx Example Self-Signed/OU=Autogenerated Certificate/CN=styx-gateway.local" \
  -addext "subjectAltName=DNS:styx-gateway.local,$IPS" \
  -addext "extendedKeyUsage=serverAuth" \
  -addext "keyUsage=digitalSignature, keyEncipherment"

# Set secure permissions for private key and certificate (only if files exist)

if [ -e /etc/ssl/local-private/https-privkey.pem ]; then
  chmod 600 /etc/ssl/local-private/https-privkey.pem
else
  echo "Warning: /etc/ssl/local-private/https-privkey.pem not found; skipping chmod"
fi

if [ -e /etc/ssl/local-certs/https-cert.pem ]; then
  chmod 644 /etc/ssl/local-certs/https-cert.pem
else
  echo "Warning: /etc/ssl/local-certs/https-cert.pem not found; skipping chmod"
fi

# Enable SSL and php in lighttpd
lighttpd-enable-mod fastcgi
lighttpd-enable-mod fastcgi-php-fpm
lighttpd-enable-mod ssl


# Clean
apt remove --purge -y laptop-detect
apt remove --purge -y dhcpcd-base
# Make sure default meta-package is removed to avoid unwanted upgrades
apt remove --purge -y linux-image-amd64
#apt autoremove --purge -y
# Trigger update-grub due to os-release change
update-grub

# Harden /var/tmp mount options (replace 'defaults' with noexec,nodev,nosuid)
sed -i '\|/var/tmp|s|defaults|noexec,nodev,nosuid|' /etc/fstab

# Create systemd service to resize /var/tmp LV on first boot
cat > /etc/systemd/system/styx-resize-vartmp.service <<'EOF'
[Unit]
Description=Resize /var/tmp LV to 512M (first boot only)
DefaultDependencies=false
Before=local-fs.target var-tmp.mount
After=lvm2-activation.service

[Service]
Type=oneshot
RemainAfterExit=no
# Cleanup primero (siempre se ejecuta, tenga exito o falle)
ExecStartPre=-/usr/bin/systemctl disable styx-resize-vartmp.service
ExecStartPre=-/usr/bin/rm -f /etc/systemd/system/styx-resize-vartmp.service
ExecStartPre=-/usr/bin/systemctl daemon-reload
# Luego el trabajo
ExecStartPre=-/usr/sbin/e2fsck -f -y /dev/vg_styx/vartmp
ExecStart=-/usr/sbin/lvreduce --resizefs -L 512M /dev/vg_styx/vartmp

[Install]
WantedBy=local-fs.target
EOF
chmod 644 /etc/systemd/system/styx-resize-vartmp.service
systemctl enable styx-resize-vartmp.service

# Compliance
systemctl mask ctrl-alt-del.target

# Blacklist unused/unwanted kernel modules for security hardening
BLACKLIST_DIR=/etc/modprobe.d
mkdir -p "$BLACKLIST_DIR"

BLACKLIST_MODULES=(
  sctp
  dccp
  cramfs
  freevxfs
  jffs2
  hfs
  hfsplus
  squashfs
  udf
)

for mod in "${BLACKLIST_MODULES[@]}"; do
  conf_file="$BLACKLIST_DIR/${mod}.conf"
  cat > "$conf_file" <<EOF
# ${mod} – blacklisted for security hardening
blacklist ${mod}
install ${mod} /bin/false
EOF
  chmod 644 "$conf_file"
done

echo "Blacklisted kernel modules: ${BLACKLIST_MODULES[*]}"


# ---------------------------------------------------------------------------
# Journal directory permissions – ensure mode 2750 (owner rwx, group r-x,
# others ---) so that others cannot read journal logs.
# ---------------------------------------------------------------------------

echo "Hardening journal directory permissions to 2750..."

# 1) Fix existing directories now (remove ACLs then set mode)
chmod 2750 /var/log/journal 2>/dev/null || true
find /var/log/journal -type d -exec setfacl -b {} \; -exec chmod 2750 {} \; 2>/dev/null || true

chmod 2750 /run/log/journal 2>/dev/null || true
find /run/log/journal -type d -exec setfacl -b {} \; -exec chmod 2750 {} \; 2>/dev/null || true

# 2) Ensure /run/log/journal is recreated with 2750 on every boot
mkdir -p /etc/tmpfiles.d
cat > /etc/tmpfiles.d/journal-perms.conf <<'EOF'
# Ensure journal directories use mode 2750
z /run/log/journal 2750 root systemd-journal - -
Z /run/log/journal/%m 2750 root systemd-journal - -

z /var/log/journal 2750 root systemd-journal - -
Z /var/log/journal/%m 2750 root systemd-journal - -
EOF
chmod 644 /etc/tmpfiles.d/journal-perms.conf

# Apply tmpfiles immediately
systemd-tmpfiles --create /etc/tmpfiles.d/journal-perms.conf 2>/dev/null || true

# 3) Force restrictive umask for systemd-journald so any directory or file it
#    creates (rotated journals, subdirs, etc.) can never be world-readable.
mkdir -p /etc/systemd/system/systemd-journald.service.d
cat > /etc/systemd/system/systemd-journald.service.d/umask.conf <<'EOF'
[Service]
UMask=0027
EOF
chmod 644 /etc/systemd/system/systemd-journald.service.d/umask.conf
systemctl daemon-reload 2>/dev/null || true

echo "Journal directory permissions set to 2750"

# Add systemd override for ulogd2 to set UMask and Group
mkdir -p /etc/systemd/system/ulogd2.service.d
cat > /etc/systemd/system/ulogd2.service.d/override.conf <<'EOF'
[Service]
UMask=0027
Group=adm
EOF
chmod 644 /etc/systemd/system/ulogd2.service.d/override.conf
systemctl daemon-reload 2>/dev/null || true

# Install
apt-get -o Dpkg::Options::="--force-confold" install -y chrony
# Utils
apt-get -o Dpkg::Options::="--force-confold" install -y ccze

# Clean /var/log
rm -f /var/log/README

# Styx provide network-online
# Disable network managers
systemctl mask ifupdown-wait-online.service ifupdown-pre.service ifup@.service || true
systemctl mask networking.service || true
systemctl mask systemd-networkd.service systemd-networkd-wait-online.service || true
systemctl mask NetworkManager.service NetworkManager-wait-online.service || true
systemctl mask nftables.service || true

# Setup styx es network-online target
rm -f /etc/systemd/system/network-online.target.wants/networking.service
ln -sf /lib/systemd/system/styx-gateway.service /etc/systemd/system/network-online.target.wants/styx-gateway.service
# BPF tools
#apt-get install  bpfcc-tools libbpfcc libbpfcc-dev