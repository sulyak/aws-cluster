
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
        worker_ip=$(echo "$line" | awk '{print $1}')
        worker_num=$(echo "$line" | awk '{print $2}')

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

# copy and compile mpi application file
for ip in "${ips[@]}"; do
    echo -i $pem_file -r $src_app_path ubuntu@$ip:~
    scp -i $pem_file -r $src_app_path ubuntu@$ip:~
    ssh -i $pem_file ubuntu@$ip "mpicc $src_app_path -o $app_name"
done


