echo yo

# First, get the ltpmap from 
# cat /var/emulab/boot/ltpmap > lustre-ltpmap.txt
cat ./lustre-ltpmap.txt | awk '{print $3}' | grep -v '^$' > hosts.txt
cat hosts.txt

# pip install parallel-ssh
alias pssh='parallel-ssh'
pssh -h hosts.txt -l ankushj ls
