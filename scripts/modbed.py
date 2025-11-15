import argparse
import os
import subprocess

# run_cmd: runs a shell command and returns the output
def run_cmd(cmd: str) -> str:
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    out, _ = p.communicate()
    return out.decode("utf-8")


# get_image: get image name for exp
def get_image(exp_name: str) -> str:
    cmd_fmt = "/usr/testbed/bin/expinfo -e {exp} -n"

    if "," not in exp_name:
        exp_name = "TableFS," + exp_name

    cmd = cmd_fmt.format(exp=exp_name)
    cmd = "{cmd} | awk \'{{ print $3 }}\'".format(cmd=cmd)
    print("Running cmd:", cmd)
    output = run_cmd(cmd)
    output = [l for l in output.split("\n") if len(l.strip())]
    images = [l for l in output if '-64-' in l]
    return images[0]


# gen_nsfile: generate ns file for modexp
def gen_nsfile(nnodes: int, fpath: str, image: str) -> None:
    ns_header = """set ns [new Simulator]
source tb_compat.tcl

"""

    ns_node_fmt = """\tset {node} [$ns node]
\ttb-set-node-os ${node} """ + image + """
\ttb-set-node-startcmd ${node} "/share/testbed/bin/generic-startup"
\t${node} add-desire wfok 1.0
\t${node} add-desire wf 1.0

"""

    ns_footer = """
$ns rtproto Static
$ns run
"""
    ns_file = ns_header

    for n in range(nnodes):
        ns_node = ns_node_fmt.format(node="h"+str(n))
        # print(ns_node)
        ns_file += ns_node

    ns_file += ns_footer

    with open(fpath, 'w') as f:
        f.write(ns_file)


# mod_exp: run modexp with generated ns file
def mod_exp(exp_name: str, nnodes: int, image: str) -> None:
    ns_fpath = "/tmp/ns.file"
    proj_name = "TableFS"

    gen_nsfile(nnodes, ns_fpath, image)

    #print "Generated ns file for experiment: ", exp_name
    print(f"Generated nsfile for exp: {exp_name} at {ns_fpath}")

    cmd = "/usr/testbed/bin/nscheck /tmp/ns.file"
    print(f"Runing: {cmd}")
    os.system(cmd)

    if "," not in exp_name:
        exp_fullname = proj_name + "," + exp_name
    else:
        exp_fullname = exp_name
#
    cmd = "/usr/testbed/bin/modexp {cmd_args} -e {exp} {nsfile}"
    cmd_args = "-w -N" # foreground + suppress email
    cmd = cmd.format(cmd_args=cmd_args, project=proj_name, exp=exp_fullname, nsfile=ns_fpath)
    print(f"Running: {cmd}")
    os.system(cmd)


def parse_args() -> argparse.Namespace:
    # args: -e <exp_name> -n <nnodes>
    parser = argparse.ArgumentParser(description="Generate and run a modexp")
    parser.add_argument("-g", "--gen", help="Only gen nsfile", required=False)
    parser.add_argument("-e", "--exp", help="Experiment name", required=False)
    parser.add_argument("-n", "--nnodes", help="Number of nodes", required=True, type=int)
    parser.add_argument("-i", "--image", help="Image to load", required=False, type=str)
    parser.add_argument("-y", "--yes", help="Skip confirmation", action="store_true", required=False, default=False)
    args = parser.parse_args()

    if args.gen:
        gen_fpath = args.gen
        par_dir = os.path.dirname(gen_fpath)
        assert os.path.exists(par_dir), "Error: Directory does not exist"
    else:
        if not args.exp:
            print("Error: Missing required arguments")
            parser.print_help()
            exit(1)

    if not args.image:
        args.image = get_image(args.exp)

    print("Experiment name:", args.exp)
    print("Number of nodes:", args.nnodes)
    print("Image:", args.image)

    return args


def run() -> None:
    args = parse_args()
    if not args.yes:
        input("Press ENTER to proceed. ")

    # args.image is automatically resolved if args.exp is set
    if args.gen:
        gen_nsfile(args.nnodes, args.gen, args.image)
    else:
        mod_exp(args.exp, args.nnodes, args.image)


if __name__ == "__main__":
    run()
