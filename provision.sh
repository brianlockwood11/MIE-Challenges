#!/usr/bin/env bash

dnf update -y

dnf install -y dhcpd
dnf install -y syslinux tftp-server tftp 

nmcli connection add type ethernet con-name eth1 ifname eth1 ipv4.addresses 10.10.100.99/24 ipv4.gateway 10.10.100.1 ipv4.dns 8.8.8.8 ipv4.method manual
systemctl restart NetworkManager


sudo cp /usr/lib/systemd/system/tftp.service /etc/systemd/system/tftp-server.service
sudo cp /usr/lib/systemd/system/tftp.socket /etc/systemd/system/tftp-server.socket

cat <<EOF > /etc/dhcp/dhcpd.conf
# DHCP Server Configuration File
default-lease-time 600;
max-lease-time 7200;


subnet 10.10.100.0 netmask 255.255.255.0 {
  authoritative;
  interface eth1;
  range 10.10.100.100 10.10.100.200;
  option routers 10.10.100.1;
  option subnet-mask 255.255.255.0;
  option domain-name-servers 8.8.8.8, 8.8.4.4;
  option domain-name "mie.local";
  next-server 10.10.100.99;
  filename "netboot.xyz.kpxe";
}
EOF

cat <<EOF > /etc/sysconfig/dhcpd
DHCPDARGS=eth1;
EOF

cat <<EOF > /etc/systemd/system/tftp-server.service
[Unit]
Description=Tftp Server
Requires=tftp-server.socket
Documentation=man:in.tftpd

[Service]
ExecStart=/usr/sbin/in.tftpd -c -p -s /var/lib/tftpboot
StandardInput=socket

[Install]
WantedBy=multi-user.target
Also=tftp-server.socket
EOF



mkdir -p /var/lib/tftpboot
cd /var/lib/tftpboot
wget -P /var/lib/tftpboot https://boot.netboot.xyz/ipxe/netboot.xyz.kpxe
chmod 777 /var/lib/tftpboot

systemctl daemon-reload
systemctl enable tftp-server
systemctl start tftp-server 
systemctl enable dhcpd
systemctl start dhcpd




systemctl restart dhcpd
