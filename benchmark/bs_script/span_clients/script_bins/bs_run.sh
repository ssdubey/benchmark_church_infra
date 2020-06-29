while getopts n:h:f:o:s: option   #n=#clinets h=list of hosts c=code file i=input file s=start
do
	case "${option}"
	in
	n) client_count=${OPTARG};;
	h) hosts=${OPTARG};;
	#c) client_name=${OPTARG};; #name of the file to run. Position should be relative to a common folder. for dune, file should end with .exe,for ocamlopt, binary file name
	#i) kv_path=${OPTARG};;
	f) output_file=${OPTARG};;
	o) order=${OPTARG};;
	s) size=${OPTARG};;
	esac
done


#time ./bs 51.159.31.34 client1 /home/shashank/work/benchmark/bs_input/8020/128/5000/pre/ index > ./output/34_5k_o_n_2
#for (( c=1; c <= ${no_of_clients}; c++ ))

if [ "${order}" == "pre" ] 
then
	for (( i=1; i <= ${client_count}; i++ )) 
	do
		cmd="time ./bs_wo_lwt ${hosts} client_${i} /home/shashank/benchmark_church_infra/benchmark/bs_input/8020/128/${size}_${i}/${order}/ index > ./output/client_${i}_${output_file}"
		echo "pre not part of evaluation"
#		time ./bs_wo_lwt ${hosts} client_${i} /home/shashank/benchmark_church_infra/benchmark/bs_input/8020/128/${size}_${i}/${order}/ index& #> ./output/client_${i}_${output_file}&
		#time ./bs 51.159.31.34 client1 /home/shashank/work/benchmark/bs_input/8020/128/5000/pre/ index > ./output/34_5k_o_n_2 &
	done
else
	for (( i=1; i <= ${client_count}; i++ ))
	do
		cmd="time ./bs_wo_lwt ${hosts} client_${i} /home/shashank/benchmark_church_infra/benchmark/bs_input/8020/128/${size}_1/${order}/ index&" # > ./output/client_${i}_${output_file} &"
		echo $cmd
		./bs_wo_lwt ${hosts} client_${i} /home/shashank/benchmark_church_infra/benchmark/bs_input/8020/128/${size}_1/${order}/ index& #> ./output/client_${i}_${output_file} &
		#time ./bs 51.159.31.34 client1 /home/shashank/work/benchmark/bs_input/8020/128/5000/pre/ index > ./output/34_5k_o_n_2 &
	done
fi
