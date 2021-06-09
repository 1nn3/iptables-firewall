#!/usr/bin/env sh

set -x
set -e

config="/etc/iptables-firewall/iptables-firewall"
gw="ppp+" # gateway interface
iptables="$(which iptables)" || iptables="/usr/sbin/iptables"

. "$config"

for chain in FORWARD INPUT OUTPUT; do
	$iptables -P $chain ACCEPT
done

# Vorhandene Regeln löschen
for table in filter nat mangle; do
	$iptables -t $table -F
	$iptables -t $table -X
done

$iptables -t nat -A POSTROUTING -o $gw -j MASQUERADE

service netfilter-persistent save

