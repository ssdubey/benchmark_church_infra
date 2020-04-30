size=${1}
set_count=${2}
get_count=${3}

mkdir ${size}
cd ${size}
mkdir set
mkdir get

cd get

for (( j = 1 ; j <= ${get_count}; j++ )) ### Inner for loop ###
do
	a=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
	echo $a >> keys
	echo $a,$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${size} | head -n 1) >> kv
done
echo "----------"

cd ../set

for (( j = 1 ; j <= ${set_count}; j++ )) ### Inner for loop ###
do
        a=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
        #echo $a >> keys
        echo $a,$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${size} | head -n 1) >> kv
done
echo "----------"
