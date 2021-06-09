#!/usr/bin/env sh
# https://gitlab.torproject.org/legacy/trac/-/wikis/doc/TransparentProxy
#
# MAKE SURE SSH PORT IS NOT IN output_ports_*
# AND tor(1) IS LISTEN ON THE if INTERFACE 

set -x
set -e

iptables="$(which ip6tables)" || iptables="/usr/sbin/ip6tables"
config="/etc/iptables-firewall/iptables-firewall"
localhost="::1/128"
localnets="fc00::/7"
output_protocols=""
output_ports_tcp=""
output_ports_udp=""

tor_user="debian-tor"
tor_dns_port=9053
tor_trans_port=9040

gw="eth0" # gateway interface
if="wlan0"

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

# INPUT
$iptables -A INPUT -i $if -j localnets
$iptables -A INPUT -i $if -j localhost
$iptables -A INPUT -i $gw -j firewall
# OUTPUT
$iptables -A OUTPUT -j ACCEPT
$iptables -A OUTPUT -m owner --uid-owner $tor_user -j ACCEPT
# FORWARD
$iptables -A FORWARD -j ACCEPT

# ROUTER
$iptables -t nat -A POSTROUTING -o $gw -j MASQUERADE

# TRANSPARENT PROXY
# SSH, DHCP and (Tor-)DNS
$iptables -t nat -A PREROUTING -i $if -p tcp --dport 22 -j REDIRECT --to-ports 22
$iptables -t nat -A PREROUTING -i $if -p udp --dport 68 -j REDIRECT --to-ports 68
$iptables -t nat -A PREROUTING -i $if -p udp --dport 53 -j REDIRECT --to-ports $tor_dns_port
$iptables -t nat -A PREROUTING -i $if -p tcp --dport 53 -j REDIRECT --to-ports $tor_dns_port
# traffic
$iptables -t nat -A PREROUTING -i $if -j output_protocols
$iptables -t nat -A PREROUTING -i $if -j output_ports

# Aktuelles Regelwerk speichern - Siehe netfilter-persistent(8)
service netfilter-persistent save

