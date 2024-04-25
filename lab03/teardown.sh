# Import the configuration file
. config.sh

# Define paths and status
image_path="${IMAGES_PATH}/${1}.img"
mountpoint_path="${MOUNTPOINTS_PATH}/$1"
status="${META_PATH}/$1"

# Check if the image file exists
if [[ ! -e $image_path ]]; then
    echo "Image/container '$1' does not exist"
    exit 1
fi

# Delete status file
rm -f $status

# Retrieve loop device associated with image
# Extract '/dev/loop0' from '/dev/loop0: []: (/var/lib/poc_container/overlay/test_loop.img)'
loop_device=$(losetup --associated $image_path | cut -d: -f1)

# Unmount and delete loop device
umount $loop_device
losetup --detach-all $loop_device

# Delete image and mountpoint path
rm -rf $image_path $mountpoint_path
echo "Deletion successful: $1"

# Get list of entries in MOUNTPOINTS_PATH
entries=( $(ls $MOUNTPOINTS_PATH) )

# Iterate over entries and remove loop filesystem
for entry in "${entries[@]}"; do
    remove_loop_fs $(basename $entry)
done

# Reset iptables
iptables -t nat --flush
iptables --policy FORWARD DROP
iptables --flush FORWARD

# Delete project path
rm -rf $PROJECT_PATH

# Delete virtual interface
ifconfig $VIRTUAL_BRIDGE_NAME $GLOBAL_HOST_START_IP down
ip link delete dev $VIRTUAL_BRIDGE_NAME
echo "Virtual bridge $VIRTUAL_BRIDGE_NAME has been deleted"