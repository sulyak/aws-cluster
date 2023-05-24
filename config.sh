#!/bin/bash

# Check if the script was called with the right parameters
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <ip_file> <pem_file> <app_name> <num_process>"
    exit 1
fi

ip_file="$1"
pem_file="$2"
app_name="$3"
num_process="$4"

# Check if the files exist
if [ ! -f "$ip_file" ]; then
    echo "IP file '$ip_file' does not exist."
    exit 1
fi

if [ ! -f "$pem_file" ]; then
    echo "PEM file '$pem_file' does not exist."
    exit 1
fi

# Read the IP file and validate worker list
master_ip=""
slots=()
ips=()

while read -r line; do
    if [[ -z "$master_ip" ]]; then
        master_ip="$line"
        ips+=("$line")
    else
        worker_ip=$(echo "$line" | awk '{print $1}')
        worker_slots=$(echo "$line" | awk '{print $2}')

        if [[ -z "$worker_ip" || -z "$worker_slots" ]]; then
            echo "Invalid worker entry: $line"
            exit 1
        fi

        workers+=("$worker_ip")
        slots+=("$worker_slots")
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
echo "num_process: $num_process"
echo "app_name: $app_name"

ssh -i $pem_file ubuntu@$master_ip "rm hostfile"

# configure the slots
len=${#workers[@]}
for ((i = 0; i < len; i++)); do
    ip="${workers[i]}"
    slots="${slots[i]}"
    ssh -i $pem_file ubuntu@$master_ip "echo '$ip slots=$slots' | sudo tee -a hostfile"
done
