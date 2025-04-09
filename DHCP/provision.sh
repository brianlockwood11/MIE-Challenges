#!/usr/bin/env bash

dnf update -y

dnf install -y dhcp-server syslinux tftp-server tftp 

dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf makecache -y

dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --nobest

mkdir /docker

cat <<EOF > /docker/docker-compose.yml
---
services:
  netbootxyz:
    image: ghcr.io/netbootxyz/netbootxyz
    container_name: netbootxyz
    environment:
      - MENU_VERSION=2.0.84 # optional
      - NGINX_PORT=80 # optional
      - WEB_APP_PORT=3000 # optional
    volumes:
      - /path/to/config:/config # optional
      - /path/to/assets:/assets # optional
    ports:
      - 3000:3000  # optional, destination should match ${WEB_APP_PORT} variable above.
      - 69:69/udp
      - 8080:80  # optional, destination should match ${NGINX_PORT} variable above.
    restart: unless-stopped
EOF

systemctl enable docker
systemctl start docker
systemctl enable docker

cd /docker
docker pull ghcr.io/netbootxyz/netbootxyz
docker compose up -d

cp /usr/lib/systemd/system/tftp.service /etc/systemd/system/tftp-server.service
cp /usr/lib/systemd/system/tftp.socket /etc/systemd/system/tftp-server.socket

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
  filename "netboot.xyz-undionly.kpxe"; 
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


cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/
cp /usr/share/syslinux/memdisk /var/lib/tftpboot/
cp /usr/share/syslinux/ldlinux.c32 /var/lib/tftpboot/
cp /usr/share/syslinux/libutil.c32 /var/lib/tftpboot/



systemctl daemon-reload
systemctl enable tftp-server
systemctl start tftp-server 
systemctl enable dhcpd
systemctl start dhcpd



