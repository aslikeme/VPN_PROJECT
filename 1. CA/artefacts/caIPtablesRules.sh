#!bin/bash

 iptables -A INPUT -i lo -j ACCEPT
 iptables -A INPUT -p tcp -m multiport --dport 22,53,80,443 -j ACCEPT
 iptables -A INPUT -p udp --dport 53 -j ACCEPT
 iptables -A INPUT -m state --state NEW,ESTABLISHED -j ACCEPT
 iptables -A INPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
 iptables -A INPUT -m state --state INVALID -j DROP
 iptables -A INPUT -p tcp -s 10.128.0.12 --dport 9100 -j ACCEPT -m comment --comment prometheus_node_exporter
 iptables -A INPUT -p tcp -s 10.128.0.13 --dport 873 -j ACCEPT -m comment --comment rsync-daemon
 iptables -A INPUT -p tcp -s 10.128.0.14 --dport 873 -j ACCEPT -m comment --comment rsync-daemon
 iptables -P INPUT DROP

 iptables -P FORWARD DROP

 iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
 iptables -A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
 iptables -A OUTPUT -p udp --dport 123 -j ACCEPT -m comment --comment ntp
 iptables -A OUTPUT -o lo -j ACCEPT
 iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
 iptables -A OUTPUT -m state --state INVALID -j DROP
 iptables -A OUTPUT -p tcp -m multiport --dports 22,53,80,443 -j ACCEPT
 iptables -P OUTPUT DROP


 apt-get install iptables-persistent -y
 service netfilter-persistent save

