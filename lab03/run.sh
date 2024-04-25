# Load configuration from config.sh
source config.sh

# Function to assign an IP address based on the given present IP and increase value.
# Parameters:
#   $1: present_ip - The present IP address.
#   $2: increase - The value by which the IP address should be increased.
# Returns:
#   The upcoming IP address.
assign_ip() {
    # Store the present IP address and increase value
    present_ip=$1
    increase=$2

    # Convert the present IP address to hexadecimal representation.
    present_ip_hex=$(printf '%.2X%.2X%.2X%.2X\n' `echo $present_ip | sed -e 's/\./ /g'`)

    # Calculate the upcoming IP address in hexadecimal representation.
    upcoming_ip_hex=$(printf %.8X `echo $(( 0x$present_ip_hex + $increase ))`)

    # Convert the upcoming IP address from hexadecimal to decimal representation.
    upcoming_ip=$(printf '%d.%d.%d.%d\n' `echo $upcoming_ip_hex | sed -r 's/(..)/0x\1 /g'`)

    # Print the upcoming IP address.
    echo "$upcoming_ip"
}

# Get the default network interface
iface=$(route | grep "^default" | grep -o '[^ ]*$')

# Initialize variables for veth and vpeer addresses
veth_addr=""
vpeer_addr=""

# Get the global default IP from the file
ip_file=$GLOBAL_DEFAULT_IP

# Define the path to the container image
image_path=$IMAGES_PATH/"$container_name".img

# Define the mount point path
mountpoint_path=$MOUNTPOINTS_PATH/$container_name

# Build container command with proc and sys mounts
cmd="${@:3}"
set_path="export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
mount_proc="mount -t proc proc /proc"
mount_sys="mount -t sysfs sys /sys"
container_cmd="$set_path ; $mount_proc && $mount_sys && $cmd"

# Get the current global IP
current_global_ip=$(cat $ip_file | xargs)

# Allocate IP addresses for veth and vpeer
veth_addr=$(allocate_ip $current_global_ip 256)
vpeer_addr=$(allocate_ip $current_global_ip 257)

# Update the global IP in the file
echo $veth_addr > $ip_file

# Define veth, vpeer, and network namespace names
veth="veth0_$2"
vpeer="vpeer1_$2"
network_ns_name="netns_$2"

# Configure the network interface
# Create a new network namespace
# Add a new veth pair
# Move the vpeer end of the veth pair to the new network namespace
# Assign the IP address to the veth end and bring it up
# Assign the IP address to the vpeer end in the new network namespace and bring it up
# Set up the default route in the new network namespace
ip netns add $network_ns_name
ip link add $veth type veth peer name $vpeer
ip link set $vpeer netns $network_ns_name
ip addr add $veth_addr/$CONTAINER_MASK dev $veth
ip link set $veth up
ip netns exec $network_ns_name ip addr add $vpeer_addr/$CONTAINER_MASK dev $vpeer
ip netns exec $network_ns_name ip link set lo up
ip netns exec $network_ns_name ip link set $vpeer up
ip netns exec $network_ns_name ip route add default via $veth_addr

# Enable IP-forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Add iptables rules for NAT
iptables -t nat -A POSTROUTING -s $vpeer_addr/$CONTAINER_MASK -o $iface -j MASQUERADE
iptables -A FORWARD -i $iface -o $veth -j ACCEPT
iptables -A FORWARD -o $iface -i $veth -j ACCEPT

# Configure DNS resolver in the container
echo "nameserver 1.1.1.1" > $mountpoint_path/etc/resolv.conf

# Update the container status to "running"
status=$META_PATH/$2
echo "running" > $status

# Create a cgroup with default settings
cgroups="cpu,memory"
cgcreate -g "$cgroups:$2"

# Run the container in the new network namespace and cgroup
cgexec -g "$cgroups:$2" \
    ip netns exec $network_ns_name \
    unshare --fork --mount --pid --ipc --mount-proc \
    chroot $mountpoint_path /bin/bash -c "$container_cmd" || true

# Cleanup after the container stops
# Delete the cgroup
# Delete the veth pair
# Delete the network namespace
cgdelete "$cgroups:$2"
ip link del dev $veth
ip netns del $network_ns_name

# Update the global IP in the file
current_global_ip=$(cat $ip_file | xargs)
current_global_ip=$(allocate_ip $current_global_ip -256)
echo "$current_global_ip" > $ip_file

# Update the container status to "stopped"
status=$META_PATH/$2
echo "stopped" > $status