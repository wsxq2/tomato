for ip in "${ips[@]}" ; do
    ping -c 100 $ip 
done
