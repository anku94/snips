exp=TableFS,amree

get_exp_status() {
  local exp=$1
  local prefix="/usr/testbed/bin"
  local expinfo="$prefix/expinfo"

  local status=$(ssh ops "$expinfo -e $exp -s" | tail -1)

  echo $status

  ssh ops "/usr/testbed/bin/readycount -e TableFS,amree"
  ssh ops "/usr/testbed/bin/expinfo -e TableFS,amree -n" | egrep -o "State: (.*)"
  ssh ops "/usr/testbed/bin/readycount -e TableFS,amr22wfok01"
}

validate_cmd() {
  local cmd=$1
  local all_cmds=($(ssh ops "ls /usr/testbed/bin"))

  for c in "${all_cmds[@]}"; do
    if [ "$c" = "$cmd" ]; then
      return 0
    fi
  done

  return 1
}

die() {
  echo "-ERROR- $1"
  # exit 1
}

is_ops() {
  echo "-INFO- Checking if we're on ops"

  local our_hostname=$(hostname -s)
  if [ "$our_hostname" = "ops" ]; then
    return 1
  fi

  echo "-INFO- Not on ops"

  return 0
}

get_proj_and_exp() {
  is_ops || die "Cannot get proj_and_exp from ops"

  local hostname=$(hostname)
  local proj=$(echo $hostname | cut -d. -f3)
  local exp=$(echo $hostname | cut -d. -f2)

  echo "$proj,$exp"
}

run_cmd() {
  local cmd_bin=$1
  local our_hostname=$(hostname -s)

  validate_cmd $cmd_bin || die "Invalid command: $cmd_bin"

  cmd_bin="/usr/testbed/bin/$cmd_bin"

  if [ "$our_hostname" = "ops" ]; then
    $cmd_bin
  else
    ssh ops "$cmd_bin"
  fi
}

confirm_assume_yes() {
  local prompt="$1"

  echo -n "$prompt [Y/n]: "
  read -r response
  # unless response is n or N, assume yes
  if [ "$response" = "n" ] || [ "$response" = "N" ]; then
    return 1
  fi

  return 0
}

run_modexp_nops() {
  is_ops || return 0

  local -i newnodecnt=$1
  local exp_name=$(get_proj_and_exp | tail -1)

  echo "-INFO- Current exp name: $exp_name"

  # first, get cur nodecnt
  local prefix="/usr/testbed/bin"
  local image=$(get_image | tail -1)

  local cmd="$prefix/node_list -e $exp_name | tr ' ' '\n' | egrep -v '^$' | wc -l | sed 's/[^0-9]*//g'"
  echo "-INFO- Getting expnodecnt"
  local curnodecnt=$(ssh ops "$cmd")

  echo "-INFO- Current node count: $curnodecnt"
  echo "-INFO- Image: $image"

  echo "-INFO- Generating new nsfile ..."
  echo "python $HOME/scripts/modbed.py -g /tmp/ns.file -n $newnodecnt -i $image"

  # now, gen new nsfile
  ssh -t ops "python $HOME/scripts/modbed.py -g /tmp/ns.file -n $newnodecnt -i $image"

  # flags: foreground + no email
  cmd="/usr/testbed/bin/modexp -w -N"
  cmd="$cmd -e $(get_proj_and_exp | tail -1) /tmp/ns.file"

  echo "-INFO- Cur node count: $curnodecnt, New node count: $newnodecnt"
  echo "-INFO: Command: $cmd"

  confirm_assume_yes "Proceed with modexp?"
  # if ret is 0, return from this function
  [ $? -eq 0 ] || return 0

  echo "-INFO- Running modexp"

  ssh ops "$cmd"

  $HOME/scripts/run-ansible.sh -a
  $HOME/scripts/run-ansible.sh -c
}

get_image() {
  local prefix="/usr/testbed/bin"
  local expinfo="$prefix/expinfo"

  pexp=$(get_proj_and_exp | tail -1)
  image=$(ssh ops "$expinfo -e $pexp -n" | egrep -o "UBUNTU[^ ]+" | uniq)

  echo $image
}

run_readycount_nops() {
  is_ops || die "Cannot run_modexp_nops from ops"

  local -i newnodecnt=$1
  local exp_name=$(get_proj_and_exp)

  # first, get cur nodecnt
  local prefix="/usr/testbed/bin"
  local readycnt=/usr/testbed/bin/readycount

  echo "Exp: $exp_name"
  ssh ops "$readycnt -e $exp_name"
}

alias modexp=run_modexp_nops
alias readycnt=run_readycount_nops
