START=$(date +%s%3N)
sleep 5
END=$(date +%s%3N)
DIFF=$(( $END - $START ))
echo "It took $DIFF nanoseconds"
