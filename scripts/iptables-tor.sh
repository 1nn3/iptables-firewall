#!/usr/bin/env sh

set -x
set -e

iptables="$(command -v iptables)" || iptables="/usr/sbin/iptables"

config="/etc/iptables-firewall/config"

localhost="127.0.0.0/8"
localnets="0.0.0.0/8,10.0.0.0/8,100.64.0.0/10,127.0.0.0/8,169.254.0.0/16,172.16.0.0/12,192.0.0.0/24,192.0.2.0/24,192.168.0.0/16,192.88.99.0/24,198.18.0.0/15,198.51.100.0/24,203.0.113.0/24,224.0.0.0/4,240.0.0.0/4,255.255.255.255/32"

# Erlaube eingehenden Verbindungen für folgende Netzwerkschnittstellen
listen_interfaces=""

# Erlaube eingehende Verbindungen an folgenden Ports
listen_ports_tcp=""
listen_ports_udp=""

# Erlaube ausgehenden Verbindungen für folgende Netzwerkschnittstellen
output_interfaces=""

# Erlaube ausgehenden Verbindungen für folgenden Protokolle
output_protocols="icmp"

# Erlaube ausgehende Verbindungen nur auf Ports, deren Protokolle
# standardmäßig verschlüsselt sind
output_ports_tcp="22,443,465,993,995,1194,6697,5222"
output_ports_udp="1194,5222"

# Erlaube ausgehenden Verbindungen für folgenden UIDs und GIDs
output_users=""
output_groups="users"

ignore_users="_apt root"
ignore_groups=""
ignore_interfaces=""

tor_host="127.0.0.1"
tor_user="debian-tor"
tor_dns_port=9053
tor_trans_port=9040

. "$config"

# Standardverhalten: Keine Verbindungen erlauben
for chain in FORWARD INPUT OUTPUT; do
	$iptables -P $chain DROP
done

# Vorhandene Regeln löschen
for table in filter nat mangle; do
	$iptables -t $table -F
	$iptables -t $table -X
done

# Erlaube localhost und lo-Interface
$iptables -N localhost
$iptables -A localhost -i lo -j ACCEPT
$iptables -A localhost -o lo -j ACCEPT
[ "$localhost" ] && $iptables -A localhost -d $localhost -j ACCEPT

# Erlaube localnets
$iptables -N localnets
[ "$localnets" ] && $iptables -A localnets -d $localnets -j ACCEPT

# Erlaube eingehende Verbindungen die zu bestehenden ausgehenden Verbindungen gehören
$iptables -N firewall
$iptables -A firewall -m state --state RELATED,ESTABLISHED -j ACCEPT

# Erlaube eingehende Verbindungen and folgenden Interfaces
$iptables -N listen_interfaces
[ "$listen_interfaces" ] && for if in $listen_interfaces; do
	$iptables -A listen_interfaces -i $if -j ACCEPT
done

# Erlaube eingehende Verbindungen and folgenden Ports
$iptables -N listen_ports
[ "$listen_ports_tcp" ] && for range in $listen_ports_tcp; do
	$iptables -A listen_ports -p tcp -m multiport --dports $range -j ACCEPT
done
[ "$listen_ports_udp" ] && for range in $listen_ports_udp; do
	$iptables -A listen_ports -p udp -m multiport --dports $range -j ACCEPT
done

# Erlaube ausgehenden Verbindungen für folgende Netzwerkschnittstellen
$iptables -t nat -N output_interfaces
[ "$output_interfaces" ] && for interface in $output_interfaces; do
	$iptables -t nat -A output_interfaces -o $interface -j REDIRECT --to-ports $tor_trans_port
done

# Erlaube ausgehenden Verbindungen für folgende Protokolle
$iptables -t nat -N output_protocols
[ "$output_protocols" ] && for protocol in $output_protocols; do
	$iptables -t nat -A output_protocols -p $protocol -j REDIRECT --to-ports $tor_trans_port
done

# Erlaube ausgehende Verbindungen an folgenden Ports
$iptables -t nat -N output_ports
[ "$output_ports_tcp" ] && for range in $output_ports_tcp; do
	$iptables -t nat -A output_ports -p tcp -m multiport --dports $range -j REDIRECT --to-ports $tor_trans_port
done
[ "$output_ports_udp" ] && for range in $output_ports_udp; do
	$iptables -t nat -A output_ports -p udp -m multiport --dports $range -j REDIRECT --to-ports $tor_trans_port
done

# Erlaube ausgehenden Verbindungen für folgende UIDs und GIDs
$iptables -t nat -N output_users_and_groups
[ "$output_users" ] && for uid in $output_users; do
	$iptables -t nat -A output_users_and_groups -p icmp -m owner --uid-owner $uid -j REDIRECT --to-ports $tor_trans_port
	$iptables -t nat -A output_users_and_groups -p tcp -m owner --uid-owner $uid -j REDIRECT --to-ports $tor_trans_port
	$iptables -t nat -A output_users_and_groups -p udp -m owner --uid-owner $uid -j REDIRECT --to-ports $tor_trans_port
done
[ "$output_groups" ] && for gid in $output_groups; do
	$iptables -t nat -A output_users_and_groups -p icmp -m owner --gid-owner $gid -j REDIRECT --to-ports $tor_trans_port
	$iptables -t nat -A output_users_and_groups -p tcp -m owner --gid-owner $gid -j REDIRECT --to-ports $tor_trans_port
	$iptables -t nat -A output_users_and_groups -p udp -m owner --gid-owner $gid -j REDIRECT --to-ports $tor_trans_port
done

$iptables -N ignore_users_and_groups
[ "$ignore_users" ] && for uid in $ignore_users; do
	$iptables -A ignore_users_and_groups -m owner --uid-owner $uid -j ACCEPT
done
[ "$ignore_groups" ] && for gid in $ignore_groups; do
	$iptables -A ignore_users_and_groups -m owner --gid-owner $gid -j ACCEPT
done

$iptables -N ignore_interfaces
[ "$ignore_interfaces" ] && for if in $ignore_interfaces; do
	$iptables -A ignore_interfaces -o $if -j ACCEPT
done

# INPUT
$iptables -A INPUT -j listen_ports
$iptables -A INPUT -j listen_interfaces
$iptables -A INPUT -j localhost
$iptables -A INPUT -j firewall

# OUTPUT
$iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $tor_dns_port
$iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $tor_dns_port
$iptables -t nat -A OUTPUT -d $localhost -j RETURN
$iptables -t nat -A OUTPUT -d $localnets -j RETURN
$iptables -t nat -A OUTPUT -j output_interfaces
$iptables -t nat -A OUTPUT -j output_protocols
$iptables -t nat -A OUTPUT -j output_ports
$iptables -t nat -A OUTPUT -j output_users_and_groups
$iptables -A OUTPUT -m owner --uid-owner $tor_user -j ACCEPT
$iptables -A OUTPUT -j ignore_interfaces
$iptables -A OUTPUT -j ignore_users_and_groups
$iptables -A OUTPUT -j localhost
$iptables -A OUTPUT -j localnets

