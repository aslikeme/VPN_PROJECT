#!bin/bash

eth=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
proto="udp"
port=1194

 iptables -A INPUT -i "$eth" -mstate --state NEW -p "$proto" --dport "$port" -j ACCEPT
 iptables -A INPUT -i tun+ -j ACCEPT
 iptables -A INPUT -p tcp -m multiport --dport 22,53,80,443 -j ACCEPT
 iptables -A INPUT -p udp --dport "$port" -j ACCEPT
 iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
 iptables -A INPUT -i lo -j ACCEPT
 iptables -A INPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
 iptables -A INPUT -m state --state INVALID -j DROP
 iptables -A INPUT -p tcp -s 10.128.0.12 --dport 9100 -j ACCEPT -m comment --comment prometheus_node_exporter
 iptables -A INPUT -p tcp -s 10.128.0.12 --dport 9176 -j ACCEPT -m comment --comment prometheus_openvpn_exporter
 iptables -A INPUT -p tcp -s 10.128.0.13 --dport 873 -j ACCEPT -m comment --comment rsync-daemon
 iptables -A INPUT -p tcp -s 10.128.0.14 --dport 873 -j ACCEPT -m comment --comment rsync-daemon
 iptables -P INPUT DROP

 iptables -A FORWARD -i tun+ -j ACCEPT
 iptables -A FORWARD -i tun+ -o "$eth" -m state --state RELATED,ESTABLISHED -j ACCEPT
 iptables -A FORWARD -i "$eth" -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
 iptables -P FORWARD DROP

 iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$eth" -j MASQUERADE

 iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
 iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
 iptables -A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
 iptables -A OUTPUT -o lo -j ACCEPT
 iptables -A OUTPUT -p udp --dport 123 -j ACCEPT -m comment --comment ntp
 iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
 iptables -A OUTPUT -m state --state INVALID -j DROP
 iptables -A OUTPUT -p tcp -m multiport --dports 22,80,443 -j ACCEPT
 iptables -P OUTPUT DROP



 apt-get install iptables-persistent -y
 service netfilter-persistent save

 sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf &>/dev/null &&  sysctl -p &> /dev/null 
 sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw &> /dev/null 
