for i in $(seq 0 9)
do
    echo "4'd$i: fonts = 512'h" `cat $i | ruby b2h.rb`";"
done
