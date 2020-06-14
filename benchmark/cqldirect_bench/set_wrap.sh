#!/bin/bash
ip=${1}
client_count=${2}
echo "truncating..."
cqlsh ${ip} -e "truncate irmin_scylla.atomic_write;"
echo "setting..."

if [ ${client_count} -eq 1 ] 
then
#1 client
./w_cqlscript.sh 1 24 1 ${ip}
elif [ ${client_count} -eq 2 ]
then
#2 client
./w_cqlscript.sh 1 12 1 ${ip}
./w_cqlscript.sh 1 12 2 ${ip}

elif [ ${client_count} -eq 3 ] 
then	
#3 client
./w_cqlscript.sh 1 8 1 ${ip}
./w_cqlscript.sh 1 8 2 ${ip}
./w_cqlscript.sh 1 8 3 ${ip}

else
	echo "wrong client no."
fi
