for i in /usr/local/lib/libpmi*; do  echo $i; echo `basename $i`; sudo rm /usr/lib/`basename $i`;  done
for i in /usr/local/lib/libpmi*; do  echo $i; echo `basename $i`; sudo ln -s $i /usr/lib/`basename $i`;  done

for i in /usr/local/include/pmi*; do  echo $i; echo `basename $i`; sudo rm /usr/include/`basename $i`; done
for i in /usr/local/include/pmi*; do  echo $i; echo `basename $i`; sudo ln -s $i /usr/include/`basename $i`;  done
