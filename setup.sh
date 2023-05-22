#!/bin/bash

# Check if the script was called with the right parameters
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <ip_file> <pem_file> <src_app_path> <app_name>"
    exit 1
fi

ip_file="$1"
pem_file="$2"
src_app_path="$3"
app_name="$4"

# Check if the files exist
if [ ! -f "$ip_file" ]; then
    echo "IP file '$ip_file' does not exist."
    exit 1
fi

if [ ! -f "$pem_file" ]; then
    echo "PEM file '$pem_file' does not exist."
    exit 1
fi

if [ ! -f "$src_app_path" ]; then
    echo "source file '$src_app_path' does not exist."
    exit 1
fi

# Read the IP file and validate worker list
master_ip=""
workers=()
ips=()

while read -r line; do
    if [[ -z "$master_ip" ]]; then
        master_ip="$line"
        ips+=("$line")
    else
        worker_ip="${line% *} "  # Extract the worker IP
        worker_num="${line##* }"  # Extract the worker number

        if [[ -z "$worker_ip" || -z "$worker_num" ]]; then
            echo "Invalid worker entry: $line"
            exit 1
        fi

        workers+=("$worker_ip")
        ips+=("$worker_ip")
    fi
done < "$ip_file"

# Check if there's at least one worker
if [ "${#workers[@]}" -lt 1 ]; then
    echo "Worker list must have at least one worker."
    exit 1
fi

# Print the extracted values for verification
echo "Master IP: $master_ip"
echo "Worker IPs: ${workers[@]}"
echo "PEM file: $pem_file"

chmod 400 $pem_file

# update everything 
for ip in "${ips[@]}"; do
    ssh-keyscan $ip >> ~/.ssh/known_hosts
    ssh -i $pem_file ubuntu@$ip "echo '$(cat $pem_file)' > .ssh/id_rsa; chmod 600 .ssh/id_rsa"
    ssh -i $pem_file ubuntu@$ip "sudo apt-get update && sudo apt-get install openssh-server openssh-client && sudo apt-get install libopenmpi-dev -y && mpiexec --version"
done

# generate master keypair
ssh -i $pem_file ubuntu@$master_ip "sudo ssh-keygen -q -t rsa -N '' -f .ssh/id_rsa <<<y 2>&1>/dev/null"

# put masters pub key
for ip in "${workers[@]}"; do
    ssh -i $pem_file ubuntu@$ip "echo $(ssh -i $pem_file ubuntu@$master_ip "cat .ssh/id_rsa.pub") | sudo tee -a .ssh/authorized_keys"
done

# known hosts 
for $ip in "${workers[@]}"; do
    ssh -i $pem_file ubuntu@$master_ip "echo '$(ssh -i $pem_file ubuntu@$ip "ssh-keyscan -H worker_ip | grep -o '^[^#]*'")' | sudo tee -a .ssh/known_hosts"
done

# copy and compile mpi application file
for ip in "${ips[@]}"; do
    scp -i $pem_file -r $mpi_app_path ubuntu@$ip:~
    ssh -i $pem_file ubuntu@$ip "mpicc $src_app_path -o $app_name"
done


