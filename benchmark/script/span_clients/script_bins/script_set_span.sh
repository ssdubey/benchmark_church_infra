while getopts n:h:c:r:f:s: option   #n=#clinets h=list of hosts c=code file i=input file s=start
do 
 case "${option}" 
 in 
 n) no_of_clients=${OPTARG};; 
 h) hosts=${OPTARG};; 
 c) code_file=${OPTARG};; #name of the file to run. Position should be relative to a common folder. for dune, file should end with .exe,for ocamlopt, binary file name
# i) kv_path=${OPTARG};;
 r) ratio=${OPTARG};;
# k) key_path=${OPTARG};;
 f) folder=${OPTARG};;
 s) inp_size=${OPTARG};;
 esac 
done 

#echo $no_of_clients
#template: cmd="dune exec set_span/${code_file} ${hosts} ${inpfile_path} --root=." 
#template: cmd="./set ${hosts} ${inpfile_path}"

#cmd="dune exec set_span/${code_file} ${hosts} ${inpfile_path} --root=." 
#cmd="./set ${hosts} ${inpfile_path}"

#cmd="./${code_file} ${hosts} ${kv_path} ${key_path} ${inp_size}"
value_size=128
inp_path="/home/shashank/work/benchmark/input/mix/${ratio}/${inp_size}"

echo $cmd
for (( c=1; c <= ${no_of_clients}; c++ ))
do  
   cmd="./${code_file} ${hosts} ${inp_path}_${c}/${value_size}/${folder}/kv"
   echo $cmd
   $cmd&
done


#$cmd
#echo $cmd
#echo $code_file


#./span.sh -c set.exe -n 2 -i "/home/shashank/work/benchmark_irminscylla/input/hashing_overhead/1mb/kv" -h "172.17.0.2,172.17.0.3"
