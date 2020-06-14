lib_count=${1}
lib_size=128
mkdir ${lib_count}
pushd ${lib_count}
for (( j = 1 ; j <= ${lib_count}; j++ )) ### Inner for loop ###
do
	#mkdir ${lib_count}
	#pushd ${lib_count}
	
	a=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
	echo $a >> index
	echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${lib_size} | head -n 1) >> ${a}_data

	#popd ${lib_count}

        #a=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
        #echo $a >> keys
        #echo $a,$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${size} | head -n 1) >> kv
done
popd 
echo "----------"
