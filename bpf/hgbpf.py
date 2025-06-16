import logging
import os
import bccutils as ft
from bcc import BPF, table
import sys
import pandas as pd
import time

logging.basicConfig(level=logging.DEBUG, stream=sys.stdout)

ORCA_WS = '/users/ankushj/repos/orca-workspace'

ORCA_BCC_WS = f'{ORCA_WS}/bcc-install'
ORCA_BCC_LIB = f'{ORCA_BCC_WS}/lib'

ORCA_UMB_WS = f'{ORCA_WS}/orca-umb-install'
ORCA_UMB_LIB = f'{ORCA_UMB_WS}/lib'

ORCA_MAIN_WS = f'{ORCA_WS}/orca-install'
ORCA_MAIN_LIB = f'{ORCA_MAIN_WS}/lib'

LIBMON = f'{ORCA_MAIN_LIB}/libmon.so'
LIBHG = f'{ORCA_UMB_LIB}/libmercury.so'
LIBHG_DBG = f'{ORCA_UMB_LIB}/libmercury_debug.so'
LIBNA_DBG = f'{ORCA_UMB_LIB}/libna_debug.so.5'
LIBFAB = f'{ORCA_UMB_LIB}/libfabric.so.1'
LIBC = "/usr/lib/x86_64-linux-gnu/libc.so.6"
LIBIBV = "/usr/lib/x86_64-linux-gnu/libibverbs.so.1"


# get cur time as 64 bit ns
INIT_TIME = None
# print(f"INIT_TIME: {INIT_TIME}")

# Misses some symbols and is too slow
# sym_map = ft.SymMapper()
# sym_map.add_elf(LIBHG)
# sym_map.add_elf(LIBMON)

# sym, sym_elf = sym_map.get_sym(["OverlayInternal"])
# print(f"sym: {sym}, sym_elf: {sym_elf}")


tracer = ft.Tracer()

tracer.register_alias("libhg", LIBHG)
tracer.register_alias("libmon", LIBMON, cache=True, cache_prefixes=["_ZN3mon"])
tracer.register_alias("libna_debug", LIBNA_DBG)
tracer.register_alias("libofi", LIBFAB)
tracer.register_alias("libibv", LIBIBV)
tracer.register_alias("libc", LIBC)

tracer.add_alias_probe("libc", "malloc")


# tracer.add_alias_probe("libhg", "HG_Forward")
# tracer.add_alias_probe("libhg", "HG_Respond")
tracer.add_alias_probe("libhg", "HG_Core_event_progress")
#tracer.add_alias_probe("libhg", "HG_Core_trigger")

tracer.add_fuzzy_probe("libmon", ["OverlayInternal", "DebugReqHandler"], "DbgReqHnd")
tracer.add_fuzzy_probe("libmon", ["OverlayInternal", "DebugRespBulkCallback"], "DbgRespBulkCallback")

# tracer.add_alias_probe("libofi", "vrb_mr_regattr")
# tracer.add_alias_probe("libofi", "rxm_mr_regattr")
# tracer.add_alias_probe("libofi", "vrb_mr_reg_iface")
#tracer.add_alias_probe("libofi", "vrb_mr_cache_reg")
tracer.add_alias_probe("libofi", "vrb_mr_reg_common")
tracer.add_alias_probe("libibv", "ibv_cmd_reg_mr")
tracer.add_alias_probe("libibv", "ibv_cmd_dereg_mr")

# Called from vrb_mr_cache_reg
# tracer.add_alias_probe("libofi", "ofi_mr_cache_reg")
# tracer.add_alias_probe("libofi", "ofi_mr_cache_search")
#
# # Called from ofi_mr_cache_search
# tracer.add_alias_probe("libofi", "util_mr_uncache_entry")
# tracer.add_alias_probe("libofi", "ofi_mr_cache_flush")
#
# # Called from ofi_mr_cache_flush
# tracer.add_alias_probe("libofi", "ofi_monitor_unsubscribe")
# tracer.add_alias_probe("libofi", "ofi_rbmap_delete")
#
# # Called from util_mr_free_entry
# tracer.add_alias_probe("libofi", "ofi_buf_free")
#
# # Called from util_mr_cache_create
# tracer.add_alias_probe("libofi", "util_mr_entry_alloc")

bpf_text = tracer.gen_bpf()


b = BPF(text=bpf_text)


log_out = "hgbpf.log"
log_file = open(log_out, "w+")

# Global PID to process name mapping
pid_to_comm = {}


def print_event(event, ev_map: dict[int, str]):
    global INIT_TIME

    pid = event.pid
    evid = event.event_id
    sym = ev_map[evid]
    tsbeg = event.tsbeg
    ret = event.ret

    # tsbeg_rel = tsbeg - INIT_TIME
    if INIT_TIME is None:
        INIT_TIME = tsbeg
        tsbeg_rel = 0
    else:
        tsbeg_rel = tsbeg - INIT_TIME
    dura = event.dura

    tsbegrelus = "{:8.6f}".format(tsbeg_rel / 1e6)

    fmtstr = "[{:s}] PID[{:8d}] {:18.18s} {:8.2f} us --> ret {:d}".format(
        tsbegrelus, pid, sym, dura/1e3, ret)
    print(fmtstr)
    log_file.write(fmtstr + "\n")


def comm_callback(binst):
    """Read and populate the global PID to process name mapping"""
    global pid_to_comm
    
    try:
        pid_to_name_map = binst["pid_to_name"]
        for pid, proc_name in pid_to_name_map.items():
            comm_name = proc_name.name.decode('utf-8', errors='ignore').rstrip('\x00')
            pid_to_comm[pid.value] = comm_name
    except KeyError:
        # pid_to_name map doesn't exist (bpf_comm.c not included)
        pass


def get_comm_for_pid(pid):
    """Helper function to get process name for a PID"""
    return pid_to_comm.get(pid, f"PID_{pid}")


def aggr_callback(binst, ev_map: dict[int, str]):
    """Read and print the entire aggregated statistics table"""
    func_aggr_stats = binst["func_aggr_stats"]
    
    print("\n=== Aggregated Function Statistics ===")
    for func_key, func_stats in func_aggr_stats.items():
        pid = func_key.pid
        evid = func_key.evid
        sym = ev_map.get(evid, f"UNKNOWN_EVID_{evid}")
        comm = get_comm_for_pid(pid)
        
        totdur = func_stats.totdur
        totcnt = func_stats.totcnt
        maxdur = func_stats.maxdur
        mindur = func_stats.mindur
        
        avgdur = totdur / totcnt if totcnt > 0 else 0

        stdout = ""
        stdout += f"PID[{pid:8d}]"
        stdout += f" {comm:16s}"
        stdout += f" {sym:30s}"
        stdout += f" cnt:{totcnt:8d}"
        stdout += f" tot:{totdur/1e6:10.3f} ms"
        stdout += f" avg:{avgdur/1e3:8.2f} us"
        stdout += f" min:{mindur/1e3:8.2f} us"
        stdout += f" max:{maxdur/1e3:8.2f} us"

        print(stdout)
        log_file.write(stdout + "\n")

    func_aggr_stats.clear()


def callback(ctx, data, size):
    event = b["events"].event(data)
    print_event(event, sym_map)


# Define the schema for event collection
event_schema = ['pid', 'event_id', 'tsbeg', 'dura', 'ret', 'stack_id']
collector = ft.EventCollector(schema=event_schema)

tracer.attach_all_probes(b)
# callback = collector.create_callback(b)
b["events"].open_ring_buffer(callback)
print("Tracing calls...")

sym_map = tracer.get_sym_map()
all_dfs = []

exiting = False


while not exiting:
    try:
        # b.ring_buffer_poll(1000)
        # b.ring_buffer_poll(1000)
        #b.ring_buffer_poll(1000)
        # df = collector.to_dataframe()
        # all_dfs.append(df)
        # exiting = True
        comm_callback(b)
        aggr_callback(b, sym_map )
        time.sleep(2)
    except KeyboardInterrupt:
        exiting = True
        print("Exiting...")
        log_file.close()


# for i in range(20):
#     b.ring_buffer_poll(1000)
#     df = collector.to_dataframe()
#     all_dfs.append(df)

# Decode event IDs to symbols
# event_df = pd.concat(all_dfs)
# event_df['event_id'] = event_df['event_id'].map(sym_map)

# # Save events to CSV
# evdf_out = "/tmp/evdf.csv"
# event_df.to_csv(evdf_out, index=False)
# evdf_len = len(event_df)
# logging.info(f"Saved {evdf_len} events to {evdf_out}")
