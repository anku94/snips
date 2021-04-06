#!/usr/bin/env python

import os, sys
import argparse
import datetime

CONFIG = os.path.expanduser("~/.ssh/config")
TEMP = os.path.expanduser("~/.ssh/py.tmp.txt")

def create_backup():
    back_id =  datetime.datetime.now().second
    os.system("cp ~/.ssh/config ~/.ssh/config.bak%s" % (back_id,))

def parse_config():
    config = None
    with open(CONFIG, 'r') as f:
        config = f.readlines()
        config = [i.strip() for i in config]

    all_entries =  []
    cur_entry = []

    for line in config:
        if line.lower().startswith('host '):
            all_entries.append(cur_entry)
            cur_entry = []
        cur_entry.append(line)
    all_entries.append(cur_entry)
    all_entries.pop(0)
    #  print(all_entries)
    return all_entries

def remove_all(config, key, pattern):
    key = key.lower()
    if key[-1] != ' ':
        key += ' '

    filtered = []

    for item in config:
        lines = [line for line in item if line.lower().startswith(key)]
        if len(lines) == 0:
            continue
        line = lines[0]
        if pattern not in line:
            filtered.append(item)

        pass

    return filtered

def add_item(config, host = None, hostname = None, identityfile = None, user = None):
    if not host:
        print("No host specified")
        return

    item = []
    item.append("Host %s" % (host,))

    if hostname:
        item.append("HostName %s" % (hostname,))
    if identityfile:
        item.append("IdentityFile %s" % (identityfile,))
    if user:
        item.append("User %s" % (user,))

    config.append(item)
    return

def write_config(config):
    with open(CONFIG, 'w+') as f:
        for entry in config:
            f.write(entry[0] + '\n')
            for line in entry[1:]:
                f.write('    %s\n' % (line,))

    return

def run(args):
    if args.config:
        CONFIG = os.path.expanduser(args.config)

    create_backup()
    config = parse_config()
    if args.remove_item:
        if not (args.host or args.hostname or args.identityfile or args.user):
            print("No property specified for host")
        if args.host:
            config = remove_all(config, 'host', args.host)
        if args.hostname:
            config = remove_all(config, 'hostname', args.hostname)
        if args.identityfile:
            config = remove_all(config, 'identityfile', args.hostname)
        if args.user:
            config = remove_all(config, 'user', args.hostname)
    if args.add_item:
        print("Adding a host...")
        if not args.host:
            print("No host specified")
            return
        if not (args.hostname or args.identityfile or args.user):
            print("No property specified for host")
            return
        add_item(config,
                host = args.host,
                hostname = args.hostname,
                identityfile = args.identityfile,
                user = args.user)
    write_config(config)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", help="Specify config")
    parser.add_argument("--remove-item", help="Remove an item", action="store_true")
    parser.add_argument("--add-item", help="Add an item", action="store_true")
    parser.add_argument("--host", help="Specify host")
    parser.add_argument("--hostname", help="Specify hostname")
    parser.add_argument("--identityfile", help="Specify identity file")
    parser.add_argument("--user", help="Specify user")
    args = parser.parse_args()
    print(args)
    run(args)
