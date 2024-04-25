# Import configuration
source config.sh

# Generate required directories
mkdir -p $PROJECT_PATH $IMAGES_PATH $MOUNTPOINTS_PATH $META_PATH

# Circumvent macOS related issues
sudo -u q bash -c './_build_rootfs.sh'

# Set up network interface

# Set global IPs for containers, increase with each new container and decrease when a container is terminated
echo $GLOBAL_DEFAULT_START_IP > $GLOBAL_DEFAULT_IP
echo $GLOBAL_HOST_START_IP > $GLOBAL_HOST_IP

image_location=$IMAGES_PATH/"$container_name".img
mount_location=$MOUNTPOINTS_PATH/$container_name
capacity=$3

# Generate an empty file to be linked with loop device
fallocate -l $capacity $image_location

# Generate a loop device
loop_device=$(losetup -fP --show $image_location)

# Generate EXT4 filesystem within the loop device
mkfs.ext4 $loop_device &> /dev/null

# Mount the loop device
mkdir -p $mount_location
mount -t ext4 $loop_device $mount_location

# Copy rootfs data to mount location
tar -xf $ROOTFS_ARCHIVE_PATH -C $mount_location

# Monitor container status, starting from 'stopped'
status=$META_PATH/$container_name
echo "stopped" > $status
