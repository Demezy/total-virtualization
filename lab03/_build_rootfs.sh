# Import the configuration file
. config.sh

# Define the name of the Docker image
image_name=image_builder/ubuntu_sysbench

# Construct the Docker image with sysbench included
docker buildx build ./ -t $image_name

# Define the format to extract image details
format="{{.Repository}} {{.ID}}"

# Extract the ID of the Docker image
image_id=$(docker images --format="$format" | grep $image_name | awk '{print $2}')

# Create a Docker container from the image and get its ID
container_id=$(docker create $image_id)

# Export the root filesystem of the container to an archive
docker export $container_id -o $ROOTFS_ARCHIVE_PATH

# Delete the Docker container
docker container rm $container_id

# Delete the Docker image
docker image rm $image_id