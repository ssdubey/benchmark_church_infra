while getopts o:f:s:g: option   #n=#clinets h=list of hosts c=code file i=input file s=start
do
	 case "${option}"
		  in
		   o) opr_count=${OPTARG};;
		    f) file_count=${OPTARG};;
		     s) set_count=${OPTARG};; 
		      g) get_count=${OPTARG};;
		       esac
		  done

value_size=128
for ((i=1; i<=${file_count}; i++)) do
	mkdir ${opr_count}_${i}
	cd ${opr_count}_${i}
	/home/shashank/work/benchmark/input_script/mix/inp_script.sh ${value_size} ${set_count} ${get_count}
	cd ..
done
