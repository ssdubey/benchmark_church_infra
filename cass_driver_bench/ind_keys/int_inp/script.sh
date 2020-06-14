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
	cmd="set_tuple ${pre_load} ${i} ${ip}"
	echo ${cmd}
	time ./set_tuple ${pre_load} ${i} ${ip}& 
	cqlsh ${ip} -f copy_cmd

	echo "--------------"
done

echo "running mix..."
for ((i=0;i<${client_count};i++))
do
        time ./mix_tuple ${post_load} ${i} ${ip}&
        echo "--------------"
done

#time ./a.out 2 ${load} 2
#echo "--------------"
#time ./a.out 2 ${load} 1
