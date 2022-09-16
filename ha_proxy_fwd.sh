#!/bin/bash -xv

##script to append a config line in ha_proxy to forward a port. define port_src and port_dest.
## this also will remove port wss 443 from kamailio config and change service owner to kamailio on kamailio.

host_ip=`hostname -I | awk '{print $1}'`
host_name=`hostname -f`
rule_name="avaya_wss"
port_src="443"
port_dest="5065"
mode="tcp"
file_dest="/etc/kazoo/haproxy/haproxy.cfg"
kam_dest_cfg="/etc/kazoo/kamailio/local.cfg"

check() {
if ! [[ -f $file_dest ]]; then
	echo failed, haproxy file missing.
	exit 1
elif [[ `grep ":$port_dest\|:$port_src\|$rule_name" $file_dest | wc -l` -gt 0 ]]; then
	echo failed, rule or port already present.
	exit 1
elif ! [[ -f $kam_dest_cfg ]]; then
        echo failed, kamailio cofig file missing.
        exit 1
fi
}


append_cfg() {

sed -i 's/User=.*/User=kamailio/g' /usr/lib/systemd/system/kazoo-kamailio.service
systemctl daemon-reload

if [[ `grep KAMAILIO_USER /etc/kazoo/kamailio/options | wc -l` -gt 0 ]]; then
sed 's/KAMAILIO_USER=.*/KAMAILIO_USER=kamailio/g' -i /etc/kazoo/kamailio/options

systemctl daemon-reload
fi

if [[ `grep '^#!trydef WSS_PORT 443' $kam_dest_cfg| wc -l` -gt 0 ]]; then
	sed 's/#!trydef WSS_PORT 443//g' -i $kam_dest_cfg
fi

tee -a  $file_dest <<EOF
#------------------------------------------------------------------
# Custom Forwarding
#---------------------------------------------------------------------

frontend $rule_name_$port_src
    bind *:$port_src
    mode tcp
    default_backend $rule_name_backend_$port_dest

backend $rule_name__backend_$port_dest
    mode tcp
    server $host_name $host_ip:$port_dest
EOF
}

check
append_cfg
