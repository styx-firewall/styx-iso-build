# styx-iso-build

## Installation

After installation, Styx will keep the network interface configuration static. If a DHCP network was used during installation, that IP will be set as static.

In installations without DHCP, if an IP and gateway were provided, they will be kept.

If something goes wrong, the fallback IP will be **192.168.100.1** on the first interface detected

The default UI port is **3041**.
The service ssh will be in the default port **22**

Default username/password is admin/admin

## Secure Installation

The secure installation requires providing the `access_token=<base64url-token>` variable in the kernel boot parameters. The token must be a **256-bit (32 bytes) random value encoded in base64url** (43 characters, no padding).

If the token is missing or invalid, the installation continues normally with the default credentials (`admin`/`admin`).

Example kernel cmdline:
    BOOT_IMAGE=/vmlinuz root=/dev/vg_styx/root ro .... access_token=abc123def456ghi789jkl012mno345pqr678stu9vwx

The `admin` user password will be set using the **last 12 characters** of the token:
    Example: with token `abc123def456ghi789jkl012mno345pqr678stu9vwx`, the password will be `qr678stu9vwx`

The API and tokens will be automatically enabled for remote configuration:

curl -X POST https://x.x.x.x:3041/submit.php \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"command":"add_user","username":"alice","password":"pass123"}'


## Getting Started

    Open a browser at https://ip.ip.ip.ip:3041 and log in with user 'admin' and the password
    according to the installation method. Note: The 'root' user does not have access to the UI.

## Proxmox VM — How to set it up

If you're using Proxmox, here's what to keep in mind when creating the VM:

- **Machine type**: pick **Q35**
- **BIOS**: use **OVMF (UEFI)** — you'll need to add a small EFI disk
- **CPU**: **2 cores** at least; select `host` type for best performance
- **RAM**: **4 GB** fixed (don't use ballooning)
- **Disk**: **15 GB** is more than enough, with a **virtio-scsi-single** controller
- **Network**: probably you'll need at least **two network cards** — one for WAN (internet) and one for LAN
