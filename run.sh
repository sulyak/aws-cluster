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

read -r line < "$ip_file"
master_ip="$line"

# Print the extracted values for verification
echo "PEM file: $pem_file"
echo "num_process: $num_process"
echo "app_name: $app_name"

# run distributed application
ssh -i $pem_file ubuntu@$master_ip "mpiexec -np $num_process -hostfile hostfile ./$app_name"

