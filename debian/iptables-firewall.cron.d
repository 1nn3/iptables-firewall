#
# Regular cron jobs for the iptables-firewall package
#

# maintenance
0 4	* * *	root	[ -x /usr/bin/iptables-firewall_maintenance ] && /usr/bin/iptables-firewall_maintenance

# sort iptables rules by packet counters
0 *	* * *	root	[ -x /usr/sbin/iptables-optimizer ] && /usr/sbin/iptables-optimizer >/dev/null
0 *	* * *	root	[ -x /usr/sbin/ip6tables-optimizer ] && /usr/sbin/ip6tables-optimizer >/dev/null

