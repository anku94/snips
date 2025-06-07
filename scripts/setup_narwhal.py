import logging
import subprocess
import sys
import time
import os

from fabric import Connection, ThreadingGroup, GroupResult


class CommandGroup:
    def __init__(self, nodes: list[str]):
        logging.info(f'Nodes: {",".join(nodes)}')

        self._nodes: list[str] = nodes
        self._group = ThreadingGroup(*nodes)
        self._output_dir = "/tmp/setup-logs"

        os.makedirs(self._output_dir, exist_ok=True)

    def _log_results(self, command: str, results: GroupResult):
        for conn, result in results.items():
            host_stdout = os.path.join(self._output_dir, f"{conn.host}.stdout")
            with open(host_stdout, "w") as f:
                f.write(result.stdout)

            host_stderr = os.path.join(self._output_dir, f"{conn.host}.stderr")
            with open(host_stderr, "w") as f:
                f.write(result.stderr)

            if result.failed:
                logging.warn(f"Node: {conn.host}")
                logging.warn("stdout:", result.stdout)
                logging.warn("stderr:", result.stderr)
        else:
            logging.info(
                f"Command executed successfully on {len(self._nodes)} nodes."
                f"\tcommand: {command}"
            )

    def run_cmd(self, cmd: str):
        results = self._group.run(cmd, warn=True, hide=True)
        self._log_results(cmd, results)

    def run_sudo(self, cmd: str):
        results = self._group.sudo(cmd, warn=True, hide=True)
        self._log_results(cmd, results)

    def run_async(self, cmd: str) -> dict[Connection, tuple]:
        conn_map = {}

        for conn in self._group:
            process = conn.run(cmd, asynchronous=True)

            pstdout = os.path.join(self._output_dir, f"{conn.host}.stdout")
            pstdout_fd = open(pstdout, "w")

            pstderr = os.path.join(self._output_dir, f"{conn.host}.stderr")
            pstderr_fd = open(pstderr, "w")

            conn_map[conn] = (process, pstdout_fd, pstderr_fd)

        return conn_map

    def watch(self, conn_map: dict[Connection, tuple]):
        try:
            while conn_map:
                for conn, (p, out_fd, err_fd) in list(conn_map.items()):
                    print(conn, p)
                    if p.stdout.channel.recv_ready():
                        p.stdout.readinto(out_fd)

                    if p.stderr.channel.recv_ready():
                        p.stderr.readinto(err_fd)

                    if p.exited is not None:
                        logging.warn(f"Node {conn.host} exited with {p.exited}.")
                        out_fd.close()
                        err_fd.close()
                        del conn_map[conn]

                time.sleep(2)
        except KeyboardInterrupt:
            logging.debug("Keyboard interrupt received.")
            for conn, (p, out_fd, err_fd) in conn_map.items():
                p.terminate()
                out_fd.close()
                err_fd.close()
                del conn_map[conn]

        logging.info("All processes completed.")


def run_local_command(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout


def get_all_nodes() -> list[str]:
    cmd = ["/share/testbed/bin/emulab-listall"]
    output = run_local_command(cmd)
    nodes = output.split(",")
    nodes = [n.strip() for n in nodes]

    logging.info(f"{len(nodes)} nodes found.")

    return nodes


def cmd_install_pkgs() -> str:
    packages = [
        "infiniband-diags",
        "libgflags-dev",
        "libgtest-dev",
        "libblkid-dev",
        "socat",
        "pkg-config",
        "fio",
        "libpmem-dev",
        "libpapi-dev",
        "numactl",
        "g++-9",
        "clang-format-10",
        "htop",
        "tree",
        "silversearcher-ag",
        "sysstat",
        "ctags",
        "libnuma-dev",
        f"linux-modules-extra-{os.uname().release}",
        "linux-tools-common",
        f"linux-tools-{os.uname().release}",
        f"linux-cloud-tools-{os.uname().release}",
        "parallel",
        "ripgrep",
        "python3-venv",
    ]

    install_cmd = f"sudo apt install -y {' '.join(packages)}"
    cmd_components = [
        "export DEBIAN_FRONTEND=noninteractive",
        'export HTTP_PROXY="http://proxy.pdl.cmu.edu:3128"',
        'export HTTPS_PROXY="http://proxy.pdl.cmu.edu:3128"',
        "sudo apt update -y",
        install_cmd,
        "cd /usr/src/gtest",
        "sudo cmake . && sudo make && sudo mv lib/libg* /usr/local/lib"
        "sudo dpkg -i ~/downloads/fd_7.3.0_amd64.deb",
        "sudo dpkg -i ~/downloads/bat_0.10.0_amd64.deb",
    ]

    cmd = " && ".join(cmd_components)

    return cmd


def run_group_command(command, nodes):
    group = ThreadingGroup(*nodes)
    results = group.run(command, warn=True, hide=True)

    for conn, result in results.items():
        if result.failed:
            logging.warn(f"Node: {conn.host}")
            logging.warn("stdout:", result.stdout)
            logging.warn("stderr:", result.stderr)
    else:
        logging.info(
            f"Command executed successfully on {len(nodes)} nodes."
            f"\tcommand: {command}"
        )

    return


def get_full_hostnames(hostnames: list[str]) -> list[str]:
    hostname = os.uname().nodename
    hostname = hostname.split(".")[:3]

    full_hostnames = []
    for h in hostnames:
        full_hostnames.append(f"{h}.{hostname[1]}.{hostname[2]}")

    return full_hostnames


def run():
    # os.system("sudo /share/testbed/bin/localize-resolv")
    nodes = get_all_nodes()
    nodes = ["h0", "h1", "h2"]

    hosts = get_full_hostnames(nodes)
    print(hosts)


    print(nodes)
    cmd_group = CommandGroup(nodes)
    cmd = "~/scripts/setup-narwhal.sh -a"
    conn_map = cmd_group.run_async(cmd)
    all_items = list(conn_map.items())
    all_items
    cmd_group.watch(conn_map)

    # cmd_group.run_cmd(cmd)
    # cmd_group.run_cmd("ls")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, stream=sys.stdout)
    run()
