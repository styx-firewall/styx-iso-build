# styx-iso-build

## Installation

If a DHCP network was used during installation, that IP will be set as static on next boot.

In installations without DHCP, if an IP and gateway were provided, they will be kept.

If something goes wrong, the fallback IP will be **192.168.100.1** on the first interface detected

The default UI port is **3041**.
The SSH service will be on the default port **22**

Default username/password is `admin`/`admin`

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
  - ⚠️ **Important**: disable `pre-enrolled-keys` when adding the EFI disk, otherwise Secure Boot will block the custom kernel (`pre-enrolled-keys=0`)
- **CPU**: **2 cores** at least; select `host` type for best performance
- **RAM**: **4 GB** (fixed don't use ballooning)
- **Disk**: **10 GB** is the minimum, less will work but will not add the right partitions (fallback to default/basic partitions system)
- **Network**: since it is a router/firewall you'll probably need at least **two network cards**

## Partitions

By default, several LVM partitions are created, taking approximately 8 GB in LVM, with the rest allocated to other non-LVM system partitions. Any remaining available space is left unallocated for the administrator to assign as they see fit.
