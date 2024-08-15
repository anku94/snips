import argparse
import logging
import paramiko
import re
import sys
import time
import os

from multiprocessing import Pool
from typing import Callable, TypedDict, Literal

global logger

from ssh_manager import SSHManager

# define enum Action = Warn | Blacklist

NodeAction = Literal["warn", "blacklist"]


class Check(TypedDict):
    name: str
    cmd: str
    output_func: Callable[[str], bool]
    action: NodeAction


class CheckResult(TypedDict):
    goodnodes: list[str]
    badnodes: list[tuple[str, str]]


def tmp():
    experiments = ["amr22wfok02"]
    hosts = get_initial_hosts(experiments)
    hosts
    sshm = SSHManager(hosts)
    sort_by_hostname = lambda x: int(x[0].split(".")[0].replace("h", ""))
    ret = sshm.run_cmd("hostname")
    sorted(ret, key=sort_by_hostname)
    p
    cmd = "hostname -f | cut -d. -f 1"
    ret = sshm.run_cmd(cmd)
    sorted(ret, key=sort_by_hostname)


class CustomFormatter(logging.Formatter):
    # ANSI escape codes for colors and styles
    COLORS = {
        "DEBUG": "\x1b[37m",  # white
        "INFO": "\x1b[33m",  # yellow
        "WARNING": "\x1b[31m",  # red
        "ERROR": "\x1b[31m",  # red
        "CRITICAL": "\x1b[31m",  # red
    }
    BOLD = "\x1b[1m"
    ITALIC = "\x1b[3m"
    RESET = "\x1b[0m"

    def format(self, record):
        log_color = self.COLORS.get(record.levelname, self.RESET)
        bold_levelname = f"{self.BOLD}{record.levelname}{self.RESET}"
        italic_funcinfo = (
            f"{self.ITALIC}{self.BOLD}{record.funcName}:{record.lineno}{self.RESET}"
        )

        record.levelname = bold_levelname
        log_message = logging.Formatter.format(self, record)
        log_message = log_message.replace(
            f"{record.funcName}:{record.lineno}", italic_funcinfo
        )

        return f"{log_color}{log_message}{self.RESET}"


def run_ssh_cmd(hostname: str, cmd: str) -> str:
    logger.debug(f"Running command on host: {hostname}\n\t{cmd}")

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    ssh.connect(hostname)
    _, stdout, _ = ssh.exec_command(cmd)
    output = stdout.read().decode("utf-8")
    ssh.close()

    return output


def get_node_name(hostname: str) -> str:
    cmd = "hostname -f | cut -d. -f 1"
    try:
        output = run_ssh_cmd(hostname, cmd)
        return output.strip()
    except Exception as e:
        logger.warning(f"-ERROR- Failed to get node name for host: {hostname}:\n {e}")
        return "[UNKNOWN]"


def get_node_names(hostnames: list[str]) -> list[str]:
    nprocs = 16
    with Pool(processes=nprocs) as pool:
        results = pool.map(get_node_name, hostnames)
        return list(results)


def get_all_hosts(experiment: str) -> list[str]:
    root_host = f"h0.{experiment}.tablefs"
    cmd = "/share/testbed/bin/emulab-listall"
    output = run_ssh_cmd(root_host, cmd)
    hosts = output.strip().split(",")
    return hosts


def get_our_exp_name() -> str:
    # get hostname using the equivalent of `hostname` command
    our_hostname = os.uname().nodename
    logger.debug(f"Hostname: {our_hostname}")

    parts = our_hostname.split(".")
    exp_name = parts[1]
    logger.debug(f"Experiment name: {exp_name}")

    return exp_name


def check_throttling(hostname: str) -> bool:
    cmd = "sudo dmesg | grep throttled"

    try:
        output = run_ssh_cmd(hostname, cmd)
        is_throttling = bool(output.strip())
    except Exception as e:
        logger.warning(f"-ERROR- Failed to check host: {hostname}, assuming bad:\n {e}")
        is_throttling = True

    if is_throttling:
        logger.warning(f"Throttling found on host: {hostname}")

    return is_throttling


def check_other_hw_issues(hostname: str) -> bool:
    cmd = "sudo dmesg | egrep 'Hardware Error'"
    is_bad = False

    try:
        output = run_ssh_cmd(hostname, cmd)
        is_bad = bool(output.strip())
    except Exception as e:
        logger.warning(f"-ERROR- Failed to check host: {hostname}, assuming bad:\n {e}")
        is_bad = True

    if is_bad:
        logger.warning(f"Generic hardware issues found on host: {hostname}")

    return is_bad


def check_memory_issues(hostname: str) -> bool:
    cmd = "sudo dmesg | egrep 'MEMORY ERROR'"
    is_bad = False

    try:
        output = run_ssh_cmd(hostname, cmd)
        is_bad = bool(output.strip())
    except Exception as e:
        logger.warning(f"-ERROR- Failed to check host: {hostname}, assuming bad:\n {e}")
        is_bad = True

    if is_bad:
        logger.warning(f"Memory issues found on host: {hostname}")

    return is_bad


def get_ip(hostname: str) -> str:
    time.sleep(0.01)

    cmd = "ifconfig | grep 10.94"
    try:
        output = run_ssh_cmd(hostname, cmd)
        mobj = re.match(r"^.*inet ([0-9\.]+) .*$", output, re.DOTALL)
        if mobj is None:
            logger.warning(f"-ERROR- Failed to get IP for host: {hostname}")
            logger.warning(f"-ERROR- Output: {output}")
            return "ERROR"
        else:
            return mobj.group(1)
    except Exception as e:
        logger.warning(f"-ERROR- Failed to get IP for host: {hostname}:\n {e}")
        return "ERROR"


def get_ip_check() -> Check:
    regex = re.compile(r"^.*inet ([0-9\.]+) .*$", re.DOTALL)
    return {
        "name": "get_ip",
        "cmd": "ifconfig | grep 10.94",
        "output_func": lambda x: regex.match(x) is None,
        "action": "blacklist",
    }


def get_throttling_check() -> Check:
    return {
        "name": "check_throttling",
        "cmd": "sudo dmesg | grep throttled",
        "output_func": lambda x: bool(x.strip()),
        "action": "blacklist",
    }


def get_badmem_check() -> Check:
    return {
        "name": "check_memory_issues",
        "cmd": "sudo dmesg | egrep 'MEMORY ERROR'",
        "output_func": lambda x: bool(x.strip()),
        "action": "blacklist",
    }


def get_other_hw_issues_check() -> Check:
    return {
        "name": "check_other_hw_issues",
        "cmd": "sudo dmesg | egrep 'Hardware Error'",
        "output_func": lambda x: bool(x.strip()),
        "action": "warn",
    }


def execute_check(sshm: SSHManager, check_nodes: list[str], check: Check) -> list[str]:
    logger.info(f"Executing check: {check['name']}")
    ret = sshm.run_cmd_on_hosts(check_nodes, check["cmd"])
    badnodes = [h for h, o in ret if check["output_func"](o)]
    return badnodes


def execute_all_checks(
    sshm: SSHManager, initial_hosts: list[str], checks: list[Check]
) -> CheckResult:
    goodnodes = [n for n in initial_hosts]
    badnodes: list[tuple[str, str]] = []

    for check in checks:
        check_badnodes = execute_check(sshm, goodnodes, check)
        cname = check["name"]
        logger.info(f"Check {cname}: {len(check_badnodes)} nodes flagged")

        if check["action"] == "blacklist":
            badnodes += [(n, cname) for n in check_badnodes]
            goodnodes = [n for n in goodnodes if n not in check_badnodes]
        else:
            logger.info("Not blacklisting nodes for this check")

        for n in check_badnodes:
            logger.warning(f" - Node {n} failed check {cname}")

    for n, r in badnodes:
        logger.warning(f"Node {n} reported for reason: {r}")

    return {"goodnodes": goodnodes, "badnodes": badnodes}


def check_all_for_func(
    hostnames: list[str], badness_func: Callable[[str], bool]
) -> list[str]:
    num_processes = min(len(hostnames), 32)

    with Pool(processes=num_processes) as pool:
        results = pool.map(badness_func, hostnames)
    bad_hosts = [hostname for hostname, is_bad in zip(hostnames, results) if is_bad]
    return bad_hosts


def get_all_ips(hosts: list[str]) -> list[str]:
    num_processes = min(len(hosts), 32)

    with Pool(processes=num_processes) as pool:
        results = pool.map(get_ip, hosts)

    return results


def get_blacklist(blacklist_file: str) -> list[str]:
    if not os.path.exists(blacklist_file):
        return []

    with open(blacklist_file, "r") as f:
        blacklist = f.readlines()
        blacklist = [l.strip() for l in blacklist if len(l.strip()) > 0]

    if len(blacklist) > 0:
        logger.warning(f"Found {len(blacklist)} blacklisted hosts")
    else:
        logger.info("No blacklisted hosts found")

    return blacklist


def write_to_blacklist(blacklist_file: str, hosts: list[str]):
    with open(blacklist_file, "w") as f:
        f.write("\n".join(hosts))

    raise Exception("Not to be used!")


def append_to_blacklist(blacklist_file: str, hosts: list[str], reason: str):
    bad_nodes = get_node_names(hosts)

    for h, n in zip(hosts, bad_nodes):
        logger.warning(f"Blacklisting host: {h}/{n} (reason: {reason})")

    with open(blacklist_file, "a") as f:
        for h in hosts:
            f.write(f"{h}\n")

    key_func = lambda x: int(x.replace("wf", ""))
    bad_nodes = ",".join(sorted(set(bad_nodes), key=key_func))

    logger.warning(f"Blacklisted nodes: {bad_nodes}")


def append_to_blacklist_new(
    blacklist_file: str, blacklist_tuples: list[tuple[str, str]]
):
    with open(blacklist_file, "a") as f:
        for h, _ in blacklist_tuples:
            logger.info(f"Blacklisting host: {h}")
            f.write(f"{h}\n")


def get_initial_hosts(experiments: list[str]) -> list[str]:
    all_hosts = []

    for exp in experiments:
        logger.warning(f"Getting initial hosts for experiment: {exp}")

        exp_hosts = get_all_hosts(exp)
        for h in exp_hosts:
            hfull = f"{h}.{exp}.tablefs"
            all_hosts.append(hfull)

    logger.warning(f"Found {len(all_hosts)} initial hosts in total")

    return all_hosts


def read_file(file_path: str) -> list[str]:
    with open(file_path, "r") as f:
        return [l.strip() for l in f.readlines()]


def write_file(file_path: str, lines: list[str]):
    with open(file_path, "w") as f:
        f.write("\n".join(lines))


def get_valid_hosts(
    experiments: list[str], work_dir: str
) -> tuple[list[str], list[str]]:
    hostsbyname_file = os.path.join(work_dir, "hostsbyname.txt")
    hostsbyip_file = os.path.join(work_dir, "hostsbyip.txt")
    hostsblacklisted_file = os.path.join(work_dir, "hostsblacklisted.txt")

    if not os.path.exists(hostsbyname_file):
        hosts = get_initial_hosts(experiments)
    else:
        hosts = read_file(hostsbyname_file)

    blacklist_cur = get_blacklist(hostsblacklisted_file)
    valid_hosts = [h for h in hosts if h not in blacklist_cur]

    # throttling_hosts = check_all_for_badness(valid_hosts)
    throttling_hosts = check_all_for_func(valid_hosts, check_throttling)
    append_to_blacklist(hostsblacklisted_file, throttling_hosts, "throttling")

    badmem_hosts = check_all_for_func(valid_hosts, check_memory_issues)
    append_to_blacklist(hostsblacklisted_file, badmem_hosts, "badmem")

    other_hw_issues = check_all_for_func(valid_hosts, check_other_hw_issues)
    logger.warning("Not blacklisting nodes for other hw issues!")

    valid_hosts = [h for h in valid_hosts if h not in throttling_hosts]
    valid_host_ips = get_all_ips(valid_hosts)

    hosts_and_ips = zip(valid_hosts, valid_host_ips)
    hosts_ip_blacklist = []
    for h, ip in hosts_and_ips:
        if ip == "ERROR":
            hosts_ip_blacklist.append(h)

    valid_hosts = [h for h in valid_hosts if h not in hosts_ip_blacklist]
    valid_host_ips = [ip for ip in valid_host_ips if ip != "ERROR"]

    if len(hosts_ip_blacklist) > 0:
        append_to_blacklist(hostsblacklisted_file, hosts_ip_blacklist, "ip-error")

    write_file(hostsbyname_file, valid_hosts)
    write_file(hostsbyip_file, valid_host_ips)

    assert len(valid_hosts) == len(valid_host_ips)

    logger.info(f"Found {len(valid_hosts)} valid hosts")

    return valid_hosts, valid_host_ips


def run_all_checks_main(hosts: list[str]) -> CheckResult:
    global logger
    experiments: list[str] = [get_our_exp_name()]
    hosts = get_initial_hosts(experiments)

    all_checks: list[Check] = [
        get_ip_check(),
        get_throttling_check(),
        get_badmem_check(),
        get_other_hw_issues_check(),
    ]

    logger.info(f"Running {len(all_checks)} checks on {len(hosts)} hosts")

    sshm = SSHManager(hosts)
    unreachable_nodes = sshm.get_unreachable_hosts()
    unreachable_nodes
    check_results = execute_all_checks(sshm, hosts, all_checks)

    goodnodes = check_results["goodnodes"]
    goodnodes
    badnode_list = check_results["badnodes"]
    badnodes = [h for h, _ in badnode_list]
    get_node_name_cmd = "hostname -f | cut -d. -f 1"

    name_cmd_ret = sshm.run_cmd_on_hosts(badnodes, get_node_name_cmd)
    badnodes, badnode_names = zip(*name_cmd_ret)

    for h, name in zip(badnodes, badnode_names):
        logger.warning(f"Bad node: {h} ({name})")

    logger.warning(f"Comma-separated: {','.join(badnode_names)} (excl unreachable)")

    badnode_list

    badnode_list += [(h, "unreachable") for h in unreachable_nodes]
    logger.info(f"Good nodes: {len(goodnodes)}")
    logger.info(f"Bad nodes: {len(badnodes)} (incl unreachable nodes)")

    check_result: CheckResult = {
        "goodnodes": goodnodes,
        "badnodes": badnode_list,
    }

    return check_result


def main(work_dir: str) -> list[str]:
    experiments: list[str] = [get_our_exp_name()]

    hostsbyname_file = os.path.join(work_dir, "hostsbyname.txt")
    _ = os.path.join(work_dir, "hostsbyip.txt")
    hostsblacklisted_file = os.path.join(work_dir, "hostsblacklisted.txt")

    if not os.path.exists(hostsbyname_file):
        hosts = get_initial_hosts(experiments)
    else:
        hosts = read_file(hostsbyname_file)

    check_results = run_all_checks_main(hosts)
    valid_hosts = check_results["goodnodes"]
    blacklist_tuples = check_results["badnodes"]
    blacklist = [h for h, _ in blacklist_tuples]

    logger.info(f"Blacklisting {len(blacklist)} nodes")

    write_file(hostsbyname_file, valid_hosts)
    append_to_blacklist_new(hostsblacklisted_file, blacklist_tuples)

    return valid_hosts


def parse_args():
    # use argparse to define an output file
    # flags: -o, --output-file

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-o",
        "--output-file",
        type=str,
        required=True,
        help="Output file to write hosts to",
    )

    parser.add_argument(
        "-r",
        "--randomize",
        action="store_true",
        required=False,
        help="Randomize output hostfile order",
    )

    args = parser.parse_args()

    logger.info(f"Output file: {args.output_file}")
    # if path is absolute, parent directory must exist
    if os.path.isabs(args.output_file):
        parent_dir = os.path.dirname(args.output_file)
        assert os.path.exists(parent_dir)

    return args


def setup_logging():
    env_log_level = os.getenv("LOG_v")
    log_level: int = 1

    if env_log_level is not None:
        log_level = int(env_log_level)

    log_levels_map = {0: logging.WARNING, 1: logging.INFO, 2: logging.DEBUG}
    selected_log_level = log_levels_map[log_level]
    # selected_log_level = logging.DEBUG

    global logger
    logger = logging.getLogger(__name__)
    logger.setLevel(selected_log_level)

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(selected_log_level)

    formatter = CustomFormatter(
        "[%(levelname)8s] %(message)s (@%(funcName)s:%(lineno)d)"
    )
    handler.setFormatter(formatter)

    logger.addHandler(handler)
    logger.propagate = False

    # logger.warning("test WARNING")
    # logger.info("test INFO")
    # logger.debug("test DEBUG")


def run(output_file: str, randomize: bool = False):
    # exps = ["amrwfok140"]
    # exps = ["amrwfok124"]
    # as output is stored in /tmp, it will automatically be invalidated
    # if experiment is reswapped
    # as output also includes num_nodes as reported by emulab-listall,
    # it will also handle a change in node count
    experiments: list[str] = [get_our_exp_name()]
    nnodes: list[str] = list(map(lambda x: str(len(get_all_hosts(x))), experiments))

    exp_ncnt_pairs = ["_".join(x) for x in zip(experiments, nnodes)]
    exp_ncnt_str = "_".join(exp_ncnt_pairs)
    work_dir = f"/tmp/throttler-handling/{exp_ncnt_str}"

    logger.info("Working directory: " + work_dir)

    os.makedirs(work_dir, exist_ok=True)

    # valid_hosts, valid_ips = get_valid_hosts(experiments, work_dir)
    valid_hosts = main(work_dir)

    if randomize:
        import random

        logger.warning("Randomizing output hostfile")

        random.shuffle(valid_hosts)

    write_file(output_file, valid_hosts)


if __name__ == "__main__":
    setup_logging()
    # do_things()
    args = parse_args()
    run(args.output_file, args.randomize)
