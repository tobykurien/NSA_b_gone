#!/bin/bash
# Firewall apps - only allow apps run from "internet" group to run

#Your External Interface, e.g. eth0, wlan0
LAN=wlan0

IPTABLES="sudo /sbin/iptables"
IP6TABLES="sudo /sbin/ip6tables"

# Clear all chains
echo "Setting up firewall..."
$IPTABLES -F
$IPTABLES -X
$IPTABLES -t nat -F
$IPTABLES -t nat -X
$IPTABLES -t mangle -F
$IPTABLES -t mangle -X

$IP6TABLES -F
$IP6TABLES -X
$IP6TABLES -t nat -F
$IP6TABLES -t nat -X
$IP6TABLES -t mangle -F
$IP6TABLES -t mangle -X

# set the default policy
$IPTABLES -P INPUT DROP
$IPTABLES -P FORWARD DROP
$IPTABLES -P OUTPUT DROP

$IP6TABLES -P INPUT DROP
$IP6TABLES -P FORWARD DROP
$IP6TABLES -P OUTPUT DROP

#create internet group - this only needs to happen once
sudo groupadd internet 2>/dev/null

# allow localhost
$IPTABLES -I INPUT -i lo -j ACCEPT
$IPTABLES -I OUTPUT -p tcp -d 127.0.0.1 -j ACCEPT
$IPTABLES -I OUTPUT -p udp -d 127.0.0.1 -j ACCEPT

$IP6TABLES -I INPUT -i lo -j ACCEPT
$IP6TABLES -I OUTPUT -p tcp -d ::1 -j ACCEPT
$IP6TABLES -I OUTPUT -p udp -d ::1 -j ACCEPT

# accept WLAN traffic based on established connections
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IP6TABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# accept packets for internet group
$IPTABLES -A OUTPUT -p tcp -m owner --gid-owner internet -j ACCEPT
$IPTABLES -A OUTPUT -p udp -m owner --gid-owner internet -j ACCEPT
$IPTABLES -A OUTPUT -p icmp -m owner --gid-owner internet -j ACCEPT

$IP6TABLES -A OUTPUT -p tcp -m owner --gid-owner internet -j ACCEPT
$IP6TABLES -A OUTPUT -p udp -m owner --gid-owner internet -j ACCEPT
$IP6TABLES -A OUTPUT -p icmp -m owner --gid-owner internet -j ACCEPT

# allow DNS, as it's not associated with an owner
# TODO: limit this to only the DNS servers in /etc/resolv.conf
$IPTABLES -A OUTPUT -p udp --dport 53 -j ACCEPT

# Stop networking service, so that we can re-configure the MAC address
echo "Setting up the new MAC address..."
sudo service network-manager stop

# mac address randomisation
NEWMAC=`echo $RANDOM$RANDOM | md5sum | sed -r 's/(..)/\1:/g; s/^(.{14}).*$/\1/;'`
NEWMAC="b2:$NEWMAC" # first byte has to be even
sudo ifconfig "$LAN" down hw ether $NEWMAC
sudo ifconfig "$LAN" up
echo "New MAC address: $NEWMAC"

# restart networking services
echo "Waiting for network restart..."
sudo service network-manager start
# now wait for networking to start up
sleep 2s

# hostname randomization
NEWHOST=`tr -dc A-Za-z0-9 < /dev/urandom |head -c $(((RANDOM%15)+3))`
echo "127.0.0.1 $NEWHOST" | sudo tee -a /etc/hosts
sudo /bin/hostname "$NEWHOST"
echo "New hostname: $NEWHOST"


echo "Done."
