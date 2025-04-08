#!/usr/bin/env bash

dnf update -y

dnf install -y dhcp-server syslinux tftp-server tftp #nfs-utils 
#dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
#dnf install -y syslinux tftp-server tftp 



#nmcli connection add type ethernet con-name eth1 ifname eth1 ipv4.addresses 10.10.100.99/24 ipv4.gateway 10.10.100.1 ipv4.dns 8.8.8.8 ipv4.method manual #&& nmcli connection up eth1
#nmcli connection up eth1
#systemctl restart NetworkManager

#sleep 60
#nmcli connection up eth1
#cat <<EOF > /etc/yum.repos.d/docker.repo
#[docker-ce-stable]
#name=Docker CE Stable - \$basearch
#baseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable
#enabled=1
#gpgcheck=1
#gpgkey=https://download.docker.com/linux/fedora/gpg
#EOF
#cat <<EOF > /etc/yum.repos.d/docker.repo
#[docker-ce-stable]
#name=Docker CE Stable - \$basearch
#baseurl=https://download.docker.com/linux/centos/7/\$basearch/stable
#enabled=1
#gpgcheck=1
#gpgkey=https://download.docker.com/linux/centos/gpg
#EOF

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
#filename "netboot.xyz-undionly.kpxe";

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
#wget -P /var/lib/tftpboot https://boot.netboot.xyz/ipxe/netboot.xyz-undionly.kpxe
#wget -P /var/lib/tftpboot https://download.rockylinux.org/pub/rocky/8.10/isos/x86_64/Rocky-8.10-x86_64-minimal.iso


#mkdir -p /var/lib/tftpboot/pxelinux.cfg

cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/
cp /usr/share/syslinux/memdisk /var/lib/tftpboot/
cp /usr/share/syslinux/ldlinux.c32 /var/lib/tftpboot/
cp /usr/share/syslinux/libutil.c32 /var/lib/tftpboot/

#mkdir /rocky-iso
#mkdir /mnt/rockylinux
#wget -P /rocky-iso https://download.rockylinux.org/pub/rocky/9.5/isos/x86_64/Rocky-9.5-x86_64-minimal.iso
#wget -P /rocky-iso https://download.fedoraproject.org/pub/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.4.iso
#mount -o loop /rocky-iso/Fedora-Workstation-Live-x86_64-41-1.4.iso /mnt/rockylinux
#cp /mnt/rockylinux/images/pxeboot/vmlinuz /var/lib/tftpboot/
#cp /mnt/rockylinux/images/pxeboot/initrd.img /var/lib/tftpboot/
#umount /mnt/rockylinux
#cp /rocky-iso/Fedora-Workstation-Live-x86_64-41-1.4.iso /mnt/rockylinux/


#cat <<EOF > /var/lib/tftpboot/pxelinux.cfg/default
#DEFAULT menu.c32
#PROMPT 0
#TIMEOUT 300
#ONTIMEOUT local
#
#MENU TITLE PXE Boot Menu
#
#LABEL RockyLinux
#    MENU LABEL Install Rocky Linux
#    KERNEL vmlinuz
#    APPEND initrd=initrd.img inst.repo=nfs://10.10.100.99:/mnt/rockylinux rd.neednet=1 ip=dhcp rw
#EOF

#cat <<EOF > /etc/exports
#/mnt/rockylinux 10.10.100.0/24(ro,sync,no_root_squash)
#EOF

#inst.repo=nfs://10.10.100.99:/mnt/rockylinux rd.neednet=1 ip=dhcp rw

#cat <<EOF > /var/lib/tftpboot/menu.ipxe
##!ipxe
#set menu-timeout 5000
#set submenu-timeout 5000
#set default bootlocal
#
#menu iPXE Boot Menu
#item --gap -- ----------------------
#item bootlocal Boot from local disk
#item netbootxyz Boot Rocky ISO
#item shell Enter iPXE shell
#item reboot Reboot the system
#item poweroff Power off the system
#
#choose --timeout 5000 selected || goto bootlocal
#
#:bootlocal
#exit
#
#:netbootxyz
#kernel tftp://10.10.100.99/vmlinuz
#initrd tftp://10.10.100.99/initrd.img
#boot
#
#:shell
#shell
#
#:reboot
#reboot
#
#:poweroff
#poweroff
#EOF

#chmod -R 777 /var/lib/tftpboot
#wget -P /var/lib/tftpboot https://boot.netboot.xyz/ipxe/netboot.xyz.iso
#chmod 644 /var/lib/tftpboot/netboot.xyz.iso

systemctl daemon-reload
systemctl enable tftp-server
systemctl start tftp-server 
systemctl enable dhcpd
systemctl start dhcpd
#systemctl enable nfs-server
#systemctl start nfs-server

#exportfs -a


