# styx-iso-build

## Installation

After installation, Styx will keep the network interface configuration static. If a DHCP network was used during installation, that IP will be set as static.

In installations without DHCP, if an IP and gateway were provided, they will be kept.

If something goes wrong, the fallback IP will be **192.168.100.1** on the first interface detected

The default UI port is **3041**.
The service ssh will be in the default port **22**

Default username/password is admin/admin

## Secure Installation

The secure installation requires providing the `access_token=<uuid>` variable in the kernel boot parameters.

Example kernel cmdline:
    BOOT_IMAGE=/vmlinuz root=/dev/vg_styx/root ro .... access_token=550e8400-e29b-41d4-a716-446655440000

The `admin` user password will be set using the **last group** of the UUID:
    Example: with UUID `550e8400-e29b-41d4-a716-446655440000`, the password will be `446655440000`

The API and tokens will be automatically enabled for remote configuration:

curl -X POST https://ip.ip.ip.ip:3041/submit.php \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"command":"add_user","username":"alice","password":"pass123"}'


## Getting Started

    Open a browser at https://ip.ip.ip.ip:3041 and log in with user 'admin' and the password
    according to the installation method. Note: The 'root' user does not have access to the UI.
