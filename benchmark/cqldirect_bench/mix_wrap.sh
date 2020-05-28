ip=${1}
client_count=${2}

if [ ${client_count} -eq 1 ]
then 
#1 client
./r_cqlscript.sh 1 24 1 ${ip} &
./w_cqlscript.sh 25 30 1 ${ip} &
elif [ ${client_count} -eq 2 ]
then
#2 client
./r_cqlscript.sh 1 12 1 ${ip} &
./w_cqlscript.sh 13 15 1 ${ip} &
./r_cqlscript.sh 1 12 2 ${ip} &
./w_cqlscript.sh 13 15 2 ${ip} &
elif [ ${client_count} -eq 3 ]
then
#3 client
./r_cqlscript.sh 1 8 1 ${ip} &
./w_cqlscript.sh 9 10 1 ${ip} &
./r_cqlscript.sh 1 8 2 ${ip} &
./w_cqlscript.sh 9 10 2 ${ip} &
./r_cqlscript.sh 1 8 3 ${ip} &
./w_cqlscript.sh 9 10 3 ${ip} &
else
	echo "wrong client no."
fi
