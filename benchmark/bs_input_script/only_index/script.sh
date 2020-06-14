while getopts l:f:r:o: option   #n=#clinets h=list of hosts c=code file i=input file s=start
do
	 case "${option}"
		  in
		   l) lib_count=${OPTARG};;
		    f) file_count=${OPTARG};;
		     r) pre_count=${OPTARG};; 
		      o) post_count=${OPTARG};;
		       esac
		  done

value_size=128
mkdir ${value_size}
pushd ${value_size}

for ((f=1; f<=${file_count}; f++)) do
mkdir ${lib_count}_${f}
pushd ${lib_count}_${f}

mkdir pre
mkdir post

for ((i=1; i<=${pre_count}; i++)) do
	ind=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
	echo ${ind} >> index
done

cp index ./pre/
mv index ./post/

pushd post
for ((i=1; i<=${post_count}; i++)) do
	#pushd post
	ind=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
	echo ${ind} >> index
#        echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${value_size} | head -n 1) >> ${ind}_data
	#popd
done
popd

popd
done

popd

#for ((i=1; i<=${file_count}; i++)) do
#	mkdir ${opr_count}_${i}
#	cd ${opr_count}_${i}
#	/home/shashank/work/benchmark/input_script/mix/inp_script.sh ${value_size} ${set_count} ${get_count}
#	cd ..
#done
