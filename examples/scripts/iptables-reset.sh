#!/usr/bin/env sh

set -x
set -e

iptables="$(command -v iptables)" || iptables="/usr/sbin/iptables"

# Standardverhalten: Keine Verbindungen erlauben
for chain in FORWARD INPUT OUTPUT; do
	$iptables -P $chain ACCEPT
done

# Vorhandene Regeln löschen
for table in filter nat mangle; do
	$iptables -t $table -F
	$iptables -t $table -X
done

