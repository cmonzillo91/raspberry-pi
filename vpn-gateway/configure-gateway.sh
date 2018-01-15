#!/bin/bash
# RUN AS SUDO USER

NordVPN_User=""
NordVPN_Pass=""
while true ; do
    case "$1" in
        -nu|--nordvpn-user)
            case "$2" in
                "") echo " Please provide a user for nordvpn" exit 1;;
                *) NordVPN_User=$2 ; shift 2 ;;
            esac ;;
        -np|--nordvpn-password)
            case "$2" in
                "") echo " Please provide a password" exit 1;;
                *) NordVPN_Pass=$2 ; shift 2 ;;
            esac ;;
        *) shift ; break ;;
    esac
done


apt-get update
###################################################
# Install openvpn
###################################################
apt-get install openvpn

###################################################
# Install NordVPN Configs
###################################################
mkdir -p /etc/openvpn/nordvpn
cd /etc/openvpn/nordvpn
wget https://nordvpn.com/api/files/zip
unzip zip
rm -rf zip

# Create Credentials File
echo "$NordVPN_User
$NordVPN_Pass" > /etc/openvpn/credentials
chmod 600  /etc/openvpn/credentials

# Update NordVPN Configs
rename 's/\.nordvpn\.com\.tcp443\.ovpn/-tcp\.ovpn/' *
rename 's/\.nordvpn\.com\.udp1194\.ovpn/-udp\.ovpn/' *
rename 's/\.ovpn/\.conf/' *
sed -i 's/auth-user-pass/auth-user-pass \/etc\/openvpn\/credentials/' *.conf

cd /etc/openvpn
ln -s /etc/openvpn/nordvpn/us846-udp.conf default.conf 
systemctl enable openvpn@default.service

###################################################
# Install speedtest-cli for testing OpenVPN speed 
###################################################
apt-get install python-pip
pip install speedtest-cli


###################################################
# Setup Static Routes 
###################################################
echo "auto lo
iface lo inet loopback

auto eth0
allow-hotplug eth0
iface eth0 inet static
    address 192.168.1.50
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
" >> /etc/network/interfaces

###################################################
# Enable NAT 
###################################################
echo -e '\n#Enable IP Routing\nnet.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sysctl -p

iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -A FORWARD -i tun0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT

apt-get install iptables-persistent
systemctl enable netfilter-persistent

###################################################
# VPN Kill Switch 
###################################################
iptables -A OUTPUT -o tun0 -m comment --comment "vpn" -j ACCEPT
iptables -A OUTPUT -o eth0 -p icmp -m comment --comment "icmp" -j ACCEPT
iptables -A OUTPUT -d 192.168.1.0/24 -o eth0 -m comment --comment "lan" -j ACCEPT
iptables -A OUTPUT -o eth0 -p udp -m udp --dport 1198 -m comment --comment "openvpn" -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp -m tcp --sport 22 -m comment --comment "ssh" -j ACCEPT
iptables -A OUTPUT -o eth0 -p udp -m udp --dport 123 -m comment --comment "ntp" -j ACCEPT
iptables -A OUTPUT -o eth0 -p udp -m udp --dport 53 -m comment --comment "dns" -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp -m tcp --dport 53 -m comment --comment "dns" -j ACCEPT
#iptables -A OUTPUT -o eth0 -j DROP
iptables -A OUTPUT -o eth0 -j DROP

netfilter-persistent save

###################################################
# HTTP PROXY
###################################################
sudo apt-get install privoxy

echo -e '\n#Disable IP V6 Routing\nnet.ipv6.conf.all.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf
sysctl -p

sed -i 's/listen-address  127\.0\.0\.1:8118/listen-address  192\.168\.1\.50:8080/' /etc/privoxy/config
sed -i 's/listen-address  \[::1\]:8118//' /etc/privoxy/config

service privoxy restart