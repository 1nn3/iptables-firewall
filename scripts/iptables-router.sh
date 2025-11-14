#!/usr/bin/env sh

set -x
set -e

config="/etc/iptables-firewall/config"
gateway_interfaces="ppp+" # gateway interface
iptables="$(command -v iptables)" || iptables="/usr/sbin/iptables"

. "$config"

for chain in FORWARD INPUT OUTPUT; do
	$iptables -P $chain ACCEPT
done

# Vorhandene Regeln löschen
for table in filter nat mangle; do
	$iptables -t $table -F
	$iptables -t $table -X
done

[ "$gateway_interfaces" ] && for interface in $gateway_interfaces; do
	$iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
done

