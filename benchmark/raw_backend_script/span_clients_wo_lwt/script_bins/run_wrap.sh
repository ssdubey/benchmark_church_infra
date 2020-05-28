#./run.sh -c snitch_cas2 -h 172.17.0.2 -n 1 -s 2500&
#./run.sh -c snitch_cas3 -h 172.17.0.3 -n 1 -s 2500&

./mix_span 172.17.0.3 /home/shashank/work/benchmark/input/mix/8020/2500_1/128/set/kv /home/shashank/work/benchmark/input/mix/8020/2500_1/128/get/keys 2500
./mix_span 172.17.0.2 /home/shashank/work/benchmark/input/mix/8020/2500_2/128/set/kv /home/shashank/work/benchmark/input/mix/8020/2500_2/128/get/keys 2500
