#!/usr/bin/env sh
# IPv6 packet filtering and NAT (Kofler firewall)

set -x
set -e

iptables="$(command -v ip6tables)" || iptables="/usr/sbin/ip6tables"
config="/etc/iptables-firewall/config"
listen_ports_tcp=""
listen_ports_udp=""
listen_interfaces=""
localhost6="::1/128"
localnets6="fc00::/7"
output_ports_tcp="0:1023,1024:49151,49152:65535"
output_ports_udp="0:1023,1024:49151,49152:65535"
output_protocols="icmp"
output_users="root"
output_groups="root"
output_interfaces=""

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

# Regelkette localhost:
# Erlaube localhost und lo-Interface
$iptables -N localhost
$iptables -A localhost -i lo -j ACCEPT
$iptables -A localhost -o lo -j ACCEPT
[ "$localhost6" ] && $iptables -A localhost -d $localhost6 -j ACCEPT

# Regelkette localnets:
# Erlaube localnets
$iptables -N localnets
[ "$localnets6" ] && $iptables -A localnets -d $localnets6 -j ACCEPT

# Regelkette firewall:
# Erlaube eingehende Verbindungen die zu bestehenden ausgehenden Verbindungen gehören
$iptables -N firewall
$iptables -A firewall -m state --state RELATED,ESTABLISHED -j ACCEPT

# Regelkette listen_ports:
# Erlaube eingehende Verbindungen and folgenden Ports
$iptables -N listen_ports
[ "$listen_ports_tcp" ] && for range in $listen_ports_tcp; do
	$iptables -A listen_ports -p tcp -m multiport --dports $range -j ACCEPT
done
[ "$listen_ports_udp" ] && for range in $listen_ports_udp; do
	$iptables -A listen_ports -p udp -m multiport --dports $range -j ACCEPT
done

# Regelkette listen_interfaces:
# Erlaube eingehende Verbindungen and folgenden Interfaces
$iptables -N listen_interfaces
[ "$listen_interfaces" ] && for if in $listen_interfaces; do
	$iptables -A listen_interfaces -i $if -j ACCEPT
done

# Erlaube alle ausgehenden Verbindungen für folgende Netzwerkschnittstellen
$iptables -N output_interfaces
[ "$output_interfaces" ] && for interface in $output_interfaces; do
	$iptables -A output_interfaces -o $interface -j ACCEPT
done

# Erlaube alle ausgehenden Verbindungen für folgende Protokolle
$iptables -N output_protocols
[ "$output_protocols" ] && for protocol in $output_protocols; do
	$iptables -A output_protocols -p $protocol -j ACCEPT
done

# Regelkette output_ports:
# Erlaube ausgehende Verbindungen an folgenden Ports
$iptables -N output_ports
[ "$output_ports_tcp" ] && for range in $output_ports_tcp; do
	$iptables -A output_ports -p tcp -m multiport --dports $range -j ACCEPT
done
[ "$output_ports_udp" ] && for range in $output_ports_udp; do
	$iptables -A output_ports -p udp -m multiport --dports $range -j ACCEPT
done

# Regelkette output_users_and_groups:
# Erlaube alle ausgehenden Verbindungen für folgende UIDs und GIDs
$iptables -N output_users_and_groups
[ "$output_users" ] && for uid in $output_users; do
	$iptables -A output_users_and_groups -m owner --uid-owner $uid -j ACCEPT
done
[ "$output_groups" ] && for gid in $output_groups; do
	$iptables -A output_users_and_groups -m owner --gid-owner $gid -j ACCEPT
done

# INPUT
$iptables -A INPUT -j listen_ports
$iptables -A INPUT -j listen_interfaces
$iptables -A INPUT -j localhost
$iptables -A INPUT -j firewall
#$iptables -A INPUT -j REJECT

# OUTPUT
$iptables -A OUTPUT -j localhost
$iptables -A OUTPUT -j localnets
$iptables -A OUTPUT -j output_interfaces
$iptables -A OUTPUT -j output_protocols
$iptables -A OUTPUT -j output_ports
$iptables -A OUTPUT -j output_users_and_groups
#$iptables -A OUTPUT -j REJECT


