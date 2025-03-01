#!/usr/bin/env sh
# https://tldp.org/HOWTO/TransparentProxy-5.html
set -x
set -e

config="/etc/iptables-firewall/config"
proxy_interface="eth+" # gateway interface
proxy_port="9040" # TOR (transparent Proxy)
listen_ports_tcp="53"
# Allow SSH
listen_ports_tcp="$listen_ports_tcp,22"
listen_ports_udp="53,67:68"
output_ports_tcp="0:1023,1024:49151,49152:65535"
output_ports_udp="0:1023,1024:49151,49152:65535"

iptables="$(command -v ip6tables)" || iptables="/usr/sbin/ip6tables"

. "$config"

for chain in FORWARD INPUT OUTPUT; do
	$iptables -P $chain ACCEPT
done

# Vorhandene Regeln löschen
for table in filter nat mangle; do
	$iptables -t $table -F
	$iptables -t $table -X
done

$iptables -t nat -N output_ports
[ "$output_ports_tcp" ] && for range in $output_ports_tcp; do
	$iptables -t nat -A output_ports -p tcp -m multiport --dports $range -j REDIRECT --to-ports $proxy_port
done
[ "$output_ports_udp" ] && for range in $output_ports_udp; do
	$iptables -t nat -A output_ports -p udp -m multiport --dports $range -j REDIRECT --to-ports $proxy_port
done

$iptables -t nat -N output_protocols
[ "$output_protocols" ] && for protocol in $output_protocols; do
	$iptables -t nat -A output_protocols -p $protocol -j REDIRECT --to-ports $proxy_port
done

[ "$listen_ports_tcp" ] && for range in $listen_ports_tcp; do
	$iptables -t nat -A PREROUTING -i $proxy_interface -p tcp -m multiport --dports $range -j RETURN
done
[ "$listen_ports_udp" ] && for range in $listen_ports_udp; do
	$iptables -t nat -A PREROUTING -i $proxy_interface -p udp -m multiport --dports $range -j RETURN
done
$iptables -t nat -A PREROUTING -i $proxy_interface -j output_ports
$iptables -t nat -A PREROUTING -i $proxy_interface -j output_protocols

