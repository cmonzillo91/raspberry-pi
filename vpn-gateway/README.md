# VPN Gateway
This folder contains scripts to configure a Raspberry pi running Raspbian as a VPN Gateway. The configuration script was based off of the following github gist: https://gist.github.com/superjamie/ac55b6d2c080582a3e64.

## configure-gateway.sh
This script will install openvpn and all NordVPN configurations. It will also setup the appropriate firewall rules to enable port forwarding to the openvpn tunnel. Note that the us server 846 is the default server used in this script. This can be changed by modifying the `ln -s /etc/openvpn/nordvpn/us846-udp.conf default.conf` symbolic link creation to the server you desire. Please run the script as root. Below is an example usage of the script:

```
./configure-gateway.sh -nu <nord_vpn_username> -np <nord_vpn_password>
```
