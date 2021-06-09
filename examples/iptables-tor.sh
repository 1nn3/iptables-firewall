#!/usr/bin/env sh

set -x
set -e

iptables="$(which iptables)" || iptables="/usr/sbin/iptables"
config="/etc/iptables-firewall/iptables-firewall"
localhost="127.0.0.0/8"
localnets="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
output_protocols=""
output_ports_tcp=""
output_ports_udp=""
output_users=""
output_groups=""
output_interfaces=""

ignore_users=""
ignore_goups=""
ignore_interfaces=""

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

$iptables -N localhost
$iptables -A localhost -i lo -j ACCEPT
$iptables -A localhost -o lo -j ACCEPT
[ "$localhost" ] && $iptables -A localhost -d $localhost -j ACCEPT

$iptables -N localnets
[ "$localnets" ] && $iptables -A localnets -d $localnets -j ACCEPT

$iptables -N firewall
$iptables -A firewall -m state --state RELATED,ESTABLISHED -j ACCEPT

$iptables -N listen_ports
[ "$listen_ports_tcp" ] && for range in $listen_ports_tcp; do
	$iptables -A listen_ports -p tcp -m multiport --dports $range -j ACCEPT
done
[ "$listen_ports_udp" ] && for range in $listen_ports_udp; do
	$iptables -A listen_ports -p udp -m multiport --dports $range -j ACCEPT
done

$iptables -t nat -N output_protocols
[ "$output_protocols" ] && for protocol in $output_protocols; do
	$iptables -t nat -A output_protocols -p $protocol -j REDIRECT --to-ports $tor_trans_port
done
$iptables -t nat -N output_ports
[ "$output_ports_tcp" ] && for range in $output_ports_tcp; do
	$iptables -t nat -A output_ports -p tcp -m multiport --dports $range -j REDIRECT --to-ports $tor_trans_port
done
[ "$output_ports_udp" ] && for range in $output_ports_udp; do
	$iptables -t nat -A output_ports -p udp -m multiport --dports $range -j REDIRECT --to-ports $tor_trans_port
done

$iptables -t nat -N output_users_and_groups
[ "$output_users" ] && for uid in $output_users; do
	$iptables -t nat -A output_users_and_groups -p tcp -m owner --uid-owner $uid -j REDIRECT --to-ports $tor_trans_port
	$iptables -t nat -A output_users_and_groups -p udp -m owner --uid-owner $uid -j REDIRECT --to-ports $tor_trans_port
done
[ "$output_groups" ] && for gid in $output_groups; do
	$iptables -t nat -A output_users_and_groups -p tcp -m owner --gid-owner $gid -j REDIRECT --to-ports $tor_trans_port
	$iptables -t nat -A output_users_and_groups -p udp -m owner --gid-owner $gid -j REDIRECT --to-ports $tor_trans_port
done

$iptables -N ignore_users_and_groups
[ "$ignore_users" ] && for uid in $ignore_users; do
	$iptables -A ignore_users_and_groups -p tcp -m owner --uid-owner $uid -j ACCEPT
	$iptables -A ignore_users_and_groups -p udp -m owner --uid-owner $uid -j ACCEPT
done
[ "$ignore_groups" ] && for gid in $ignore_groups; do
	$iptables -A ignore_users_and_groups -p tcp -m owner --gid-owner $gid -j ACCEPT
	$iptables -A ignore_users_and_groups -p udp -m owner --gid-owner $gid -j ACCEPT
done

$iptables -N ignore_interfaces
[ "$ignore_interfaces" ] && for if in $ignore_interfaces; do
	$iptables -A ignore_interfaces -o $if -j ACCEPT
done

# INPUT
$iptables -A INPUT -j listen_ports
$iptables -A INPUT -j localhost
$iptables -A INPUT -j firewall

# OUTPUT
$iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $tor_dns_port
$iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $tor_dns_port
$iptables -t nat -A OUTPUT -d $localhost -j RETURN
$iptables -t nat -A OUTPUT -d $localnets -j RETURN
$iptables -t nat -A OUTPUT -j output_protocols
$iptables -t nat -A OUTPUT -j output_ports
$iptables -t nat -A OUTPUT -j output_users_and_groups
$iptables -A OUTPUT -m owner --uid-owner $tor_user -j ACCEPT
$iptables -A OUTPUT -j ignore_interfaces
$iptables -A OUTPUT -j ignore_users_and_groups
$iptables -A OUTPUT -j localhost
$iptables -A OUTPUT -j localnets

# Aktuelles Regelwerk speichern - Siehe netfilter-persistent(8)
service netfilter-persistent save

