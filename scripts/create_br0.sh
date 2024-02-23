HOST_IP=192.168.8.100
CIDR=24
GATEWAY=192.168.8.1
DNS=192.168.8.1
NWIF=enp1s0
bridge_name=br0

nmcli connection add type bridge ifname $bridge_name

nmcli connection modify bridge-$bridge_name \
ipv4.method manual \
ipv4.addresses "$HOST_IP/$CIDR" \
ipv4.gateway "$GATEWAY" \
ipv4.dns $DNS

nmcli connection add type bridge-slave ifname $NWIF master bridge-$bridge_name

nmcli connection delete $NWIF

nmcli connection up bridge-$bridge_name
