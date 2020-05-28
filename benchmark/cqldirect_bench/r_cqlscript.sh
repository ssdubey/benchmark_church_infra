start_count=${1}
end_count=${2}
tag=${3} #client tag
ip=${4}

declare -a arrkey
declare -a arrvalue

for (( c=${start_count}; c<=${end_count}; c++ )) do
        arrkey[${c}]=key_${c}
#        arrvalue[${c}]=val_${c}
done

START=$(date +%s%3N)
for (( c=${start_count}; c<=${end_count}; c++ )) do
       cqlsh ${ip} -e "select value from irmin_scylla.atomic_write where key = '${arrkey[$c]}_${tag}';"
done
END=$(date +%s%3N)
DIFF=$(( $END - $START ))
echo "It took $DIFF milliseconds in read"
