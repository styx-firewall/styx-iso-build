# styx-iso-build

# Install

Boot the ISO and start a typical Debian installation. This will install the necessary packages for Styx.

# Starting

After installation, Styx will keep the network interface configuration static. If a DHCP network was used during installation, that IP will be set as static.

In installations without DHCP, if an IP and gateway were provided, they will be kept.

If anything going wrong the fallback IP will be **192.168.100.1** in the first interface detected

The default UI port is **3041**.
The service ssh will be in the default port **22**
