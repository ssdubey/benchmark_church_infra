host=${1}
file_name_size=${2}
loop_count=${3}
no_of_clients=${4}

for((i=0; i<${loop_count}; i++)) do
	./run.sh -c ${host} -h ${host} -s ${file_name_size} -n ${no_of_clients} >> ert
done
