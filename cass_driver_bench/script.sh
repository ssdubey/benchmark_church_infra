client_count=${1}
load=${2}
#seed=${3}

for ((i=0;i<${client_count};i++)) 
do
	time ./a.out 2 ${load} ${i}& #last param is seed
#	sleep 1
	echo "--------------"
done
#time ./a.out 2 ${load} 2
#echo "--------------"
#time ./a.out 2 ${load} 1
