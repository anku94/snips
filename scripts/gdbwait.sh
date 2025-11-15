pid=""

while [ "$pid" = "" ]; do
  pid=`pidof preload-runner | awk '{ print $4 } '`
done

gdb -p $pid
