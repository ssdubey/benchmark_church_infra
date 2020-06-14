ip=${1}
client_count=${2}
pre_load=${3}
post_load=${4}
echo ${ip}
echo ${client_count}
echo ${pre_load}
echo ${post_load}

echo  "setting..."
for ((i=0;i<${client_count};i++)) 
do
	cmd="set_tuple ${pre_load} ${ip}"
	echo ${cmd}
	time ./${cmd}
	echo "--------------"
done

#sleep 5

cqlsh 51.159.31.35 -e "copy irmin_scylla.atomic_write (key) to './output.csv';"

#sleep 5
echo "running mix..."
for ((i=0;i<${client_count};i++))
do
	cmd="mix_tuple ${post_load} ${pre_load} ${ip}"
	echo ${cmd}
	time ./${cmd}&
	echo "--------------"
done

