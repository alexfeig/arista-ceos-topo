#!/bin/sh

#################
# Parse arguments
#################

TMODE=$1

if [ -z "$TMODE" ]; then
  TMODE='none'
fi


#######################
# Re-run script as sudo
#######################

if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi

###############
# Enabling LLDP
###############

lldpad -d
for i in `ls /sys/class/net/ | grep 'eth\|ens\|eno'`
do
    lldptool set-lldp -i $i adminStatus=rxtx
    lldptool -T -i $i -V sysName enableTx=yes
    lldptool -T -i $i -V portDesc enableTx=yes
    lldptool -T -i $i -V sysDesc enableTx=yes
done

################
# Teaming setup
################

cat << EOF > /home/alpine/teamd-lacp.conf
{
   "device": "team0",
   "runner": {
       "name": "lacp",
       "active": true,
       "fast_rate": true,
       "tx_hash": ["eth", "ipv4", "ipv6"]
   },
     "link_watch": {"name": "ethtool"},
     "ports": {"eth1": {}, "eth2": {}}
}
EOF

cat << EOF > /home/alpine/teamd-static.conf
{
 "device": "team0",
 "runner": {"name": "roundrobin"},
 "ports": {"eth1": {}, "eth2": {}}
}
EOF

if [ "$TMODE" == 'lacp' ]; then
  TARG='/home/alpine/teamd-lacp.conf'
else if [ "$TMODE" == 'static' ]; then
  TARG='/home/alpine/teamd-static.conf'
fi

if [ "$TMODE" == 'lacp' ] || [ "$TMODE" == 'static' ]; then
  teamd -v
  ip link set eth1 down
  ip link set eth2 down
  teamd -d -f $TARG

  ip link set team0 up
fi

################
# IP addr setup
################

$SETIP="/home/alpine/set_ip.sh"

if [ -e "$SETIP" ]; then
  chmod +x $SETIP
  $SETIP
fi

#####################
# Enter sleeping loop
#####################

while sleep 3600; do :; done