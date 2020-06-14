#echo "This approach will not work because process are running in background and they will immediately delete the content of the table for next loop."









docker exec -i cas_single cqlsh -f cmdfile; ./script_set_span.sh -c set_span -h 172.17.0.2 -r 8020 -f get -n 15 -s 66; ./script_mix_span.sh -c mix_span -h 172.17.0.2 -r 8020 -n 15 -s 66
# Case 1: Finding throughput and latency with data size of 128b with varying no. of clients and one server over mixed dataset
for ((i=0; i<5; i++)) 
do
echo "-----------start------------"
echo "running cql command to truncate"
docker exec -i bm_scylla_single cqlsh -f /cqlcmd.cql

echo "running script to insert pre-required data"
./span.sh -h "172.17.0.2" -c set_span -n 1 -i "/home/shashank/work/benchmark/input/mix/800_200/128/get/kv"

echo "running the main script"
./span.sh -h "172.17.0.2" -c mix_span -n 1 -i "/home/shashank/work/benchmark/input/mix/800_200/128/set/kv" -k "/home/shashank/work/benchmark/input/mix/800_200/128/get/keys" -s 1000

echo "------------done-----------"
done
