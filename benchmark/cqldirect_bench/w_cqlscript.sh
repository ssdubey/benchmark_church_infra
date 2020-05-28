start_count=${1}
end_count=${2}
tag=${3} #client tag
ip=${4}

declare -a arrkey
declare -a arrvalue

for (( c=${start_count}; c<=${end_count}; c++ )) do
	arrkey[${c}]=key_${c}
	arrvalue[${c}]=val_${c}
done

#		for (( c=1; c<=${1}; c++ )) do
#			                echo ${arrkey[${c}]}
#					                        echo ${arrvalue[${c}]}
#								                done
START=$(date +%s%3N)
for (( c=${start_count}; c<=${end_count}; c++ )) do
       cqlsh ${ip} -e "insert into irmin_scylla.atomic_write (key,value) values ('${arrkey[$c]}_${tag}','${arrvalue[$c]}_${tag}');"
done
END=$(date +%s%3N)
DIFF=$(( $END - $START ))
echo "It took $DIFF milliseconds"
