#! /bin/bash
while getopts n:h:c:s: option   #n=#clinets h=list of hosts c=code file i=input file s=start
do
	 case "${option}"
		  in
		   n) client=${OPTARG};;
		    h) hosts=${OPTARG};;
		     c) container=${OPTARG};; #name of the file to run. Position should be relative to a common folder. for dune, file should end with .exe,for ocamlopt, binary file name
		      #i) kv_path=${OPTARG};;
		       #k) key_path=${OPTARG};;
		        #r) ratio=${OPTARG};;
			 s) size=${OPTARG};;
			  esac
		  done


#container=${1}
#hosts=${2}
#client=${3}
#size=${4}
#docker exec -i ${container} cqlsh -f cmdfile; 
#./script_set_span.sh -c set_span -h ${hosts} -r 8020 -f get -n ${client} -s ${size}; 
./script_mix_span.sh -c mix_span -h ${hosts} -r 8020 -n ${client} -s ${size};



#./script_set_span.sh -c set_span -h ${hosts} -r 8020 -f get -n ${client} -s ${size}; taskset --cpu-list 0-3 ./script_mix_span.sh -c mix_span -h ${hosts} -r 8020 -n ${client} -s ${size};
#docker exec -i cas_single cqlsh -f cmdfile; ./script_set_span.sh -c set_span -h 172.17.0.2,172.17.0.3 -r 8020 -f get -n 1 -s 1000; ./script_mix_span.sh -c mix_span -h 172.17.0.2,172.17.0.3 -r 8020 -n 1 -s 1000

