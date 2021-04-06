function remove_cloudlab() {
  echo "Clearing cloudlab from config..."
  ~/scripts/mod-config.py --remove-item --hostname cloudlab
}

function add_host() {
  echo "Adding $1"
  ~/scripts/mod-config.py --add-item --host cl$2 --hostname $1.utah.cloudlab.us --identityfile ~/.ssh/emu/emu --user ankushj
}

# $1: node to ssh to, $2: substring in the plugin name
function vim_disable_plugin() {
  ssh $1 "sed -e '/.*$2/s/^/\" /g' -i ~/.vimrc"
}

function setup_node() {
  nid=cl$1
  scp ~/.tmux.conf $nid:~
  scp ~/.vimrc $nid:~
  ssh $nid /bin/zsh << EOF
rm -f ~/.zshrc
git clone --recursive https://github.com/sorin-ionescu/prezto.git "\${ZDOTDIR:-\$HOME}/.zprezto"
setopt EXTENDED_GLOB
for rcfile in "\${ZDOTDIR:-\$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -s "\$rcfile" "\${ZDOTDIR:-\$HOME}/.\${rcfile:t}"
done
EOF
  scp ~/.zpreztorc $nid:~
  scp ~/.zhistory $nid:~
  ssh $nid "sudo apt install -y sshfs"
  ssh $nid "sudo apt install -y cmake-curses-gui tree"

  ssh $nid "sed -e '/.*valloric/s/^/\" /g' -i ~/.vimrc"
  vim_disable_plugin $nid youcompleteme
  vim +'PlugInstall --sync' +qa
}

remove_cloudlab

node_count=1

for node in "$@";
do
  echo $node
  add_host $node $node_count
  ssh -o StrictHostKeyChecking=no cl$node_count "ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N \"\""
  setup_node $node_count
  node_count=$((node_count + 1))
done

nc=1
for node in "$@";
do
  echo $node
  scp cl$nc:~/.ssh/id_rsa.pub /tmp/key
  echo "Host *\n\tStrictHostKeyChecking no\n" | ssh cl$nc -T "cat >> ~/.ssh/config"
  ncin=1
  for dest in "$@";
  do
    echo $dest
    cat /tmp/key | ssh cl$ncin -T "cat  >> ~/.ssh/authorized_keys"
    echo "Host cl$nc" | ssh cl$ncin -T "cat  >> ~/.ssh/config"
    echo "\tHostName ankushjnode-$nc\n" | ssh cl$ncin -T "cat  >> ~/.ssh/config"
    ncin=$((ncin+1))
  done
  nc=$((nc+1))
done

# setup shared FS
nc=1
for node in "$@";
do
  echo $node
  ssh cl$nc -T "mkdir -p ~/share"
  # if [ $nc != 1 ];
  # then
    # ssh cl$nc -T "sudo sshfs -o allow_other,IdentityFile=~/.ssh/id_rsa,StrictHostKeyChecking=no ankushjnode-1:/users/ankushj/share ~/share"
  # fi
  nc=$((nc+1))
done
