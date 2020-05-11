count=${1}
tag=${2}

declare -a arrkey
declare -a arrvalue

for (( c=1; c<=${count}; c++ )) do
	        arrkey[${c}]=key_${c}
		        arrvalue[${c}]=val_${c}
		done

#		for (( c=1; c<=${1}; c++ )) do
#			                echo ${arrkey[${c}]}
#					                        echo ${arrvalue[${c}]}
#								                done
		START=$(date +%s%3N)
		for (( c=1; c<=${count}; c++ )) do
			       cqlsh 51.159.31.36 -e "insert into irmin_scylla.atomic_write (key,value) values ('${arrkey[$c]}_${tag}','${arrvalue[$c]}_${tag}');"
			done
			END=$(date +%s%3N)
			        DIFF=$(( $END - $START ))
				                echo "It took $DIFF nanoseconds"
