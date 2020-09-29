#!/bin/bash

progress() {
  PCT=$1

  RATIO=1
  TOTAL_BLOCKS=$(( 100 / $RATIO ))
  # echo $TOTAL_BLOCKS
  PCT_BLOCKS=$(( PCT / RATIO ))
  # echo $PCT_BLOCKS

  if [ $PCT_BLOCKS -ge 1 ];
  then
    for i in $(seq 1 $PCT_BLOCKS); do
      echo -n '#'
    done
  fi

  for i in $(seq $(($PCT_BLOCKS + 1)) $TOTAL_BLOCKS); do
    echo -n ' '
  done

  echo -n \($PCT\%\)'       '
  printf "\r"
}

progress_end() {
  progress 100
  echo -e ''
}

progress_test() {
  for i in $(seq 1 100); do
    progress $i
    sleep 1
  done
  progress_end
}

wait_until_multiple() {
  INTVL=$(( $1 * 60 ))

  while : ;do
    CUR_TIME=$( date +%s )
    INTVL_LEFT=$(( CUR_TIME % INTVL ))
    if [ "$INTVL_LEFT" -le 10 ]; then
      break
    fi
    printf "\r$((INTVL - INTVL_LEFT)) seconds to start...        "
    sleep 2
  done
}

run() {
  INTVL_MIN=$1
  PROG_NCHUNKS=$2

  echo -e "\n\tAlarm every $INTVL_MIN minute(s)\n"

  wait_until_multiple $INTVL_MIN

  while :
  do
    date

    INTVL_SEC=$(( INTVL_MIN * 60 ))
    CHUNKSZ=$(( INTVL_SEC / PROG_NCHUNKS ))
    INTVL_CHUNKS=$(( INTVL_SEC / CHUNKSZ ))

    for SLEEP_CYCLE in $(seq $CHUNKSZ $CHUNKSZ $INTVL_SEC);
    do
      PROG_PCT=$(( (SLEEP_CYCLE - CHUNKSZ) * 100 / INTVL_SEC ))
      progress $PROG_PCT
      sleep $CHUNKSZ
    done
    progress_end

    afplay /System/Library/Sounds/Ping.aiff
  done
}

INTVL_MIN=10
INTVL_CHUNKS=100
run $INTVL_MIN $INTVL_CHUNKS
#progress_test
