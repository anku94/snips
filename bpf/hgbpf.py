import logging
import os
import bccutils as ft
from bcc import BPF, table
import sys
import pandas as pd

ORCA_WS = '/users/ankushj/repos/orca-workspace'

ORCA_BCC_WS = f'{ORCA_WS}/bcc-install'
ORCA_BCC_LIB = f'{ORCA_BCC_WS}/lib'

ORCA_UMB_WS = f'{ORCA_WS}/orca-umb-install'
ORCA_UMB_LIB = f'{ORCA_UMB_WS}/lib'

ORCA_MAIN_WS = f'{ORCA_WS}/orca-install'
ORCA_MAIN_LIB = f'{ORCA_MAIN_WS}/lib'

LIBHG = f'{ORCA_UMB_LIB}/libmercury.so'
LIBC = "/usr/lib/x86_64-linux-gnu/libc.so.6"


# Make sure that LIBHG exists
hg_exists = os.path.exists(LIBHG)
print(f'LIBHG: {LIBHG} exists? {hg_exists}')


tracer = ft.Tracer()
# # spec = ft.ProbeSpec(name=LIBHG, sym="HG_Forward",
# #                     uprobe=True, uretprobe=True, stack=False)
spec = ft.ProbeSpec(name=LIBC, sym="fread*",
                    uprobe=True, uretprobe=True, stack=False, regex=True)
tracer.add_probe(spec)
bpf_text = tracer.gen_bpf()

logging.basicConfig(level=logging.DEBUG, stream=sys.stdout)

b = BPF(text=bpf_text)

# Define the schema for event collection
event_schema = ['pid', 'event_id', 'tsbeg', 'dura', 'ret', 'stack_id']
collector = ft.EventCollector(schema=event_schema)

tracer.attach_all_probes(b)
callback = collector.create_callback(b)
b["events"].open_ring_buffer(callback)
print("Tracing calls...")

all_dfs = []

for i in range(2):
    b.ring_buffer_poll(1000)
    df = collector.to_dataframe()
    all_dfs.append(df)

# Decode event IDs to symbols
sym_map = tracer.get_sym_map()
event_df = pd.concat(all_dfs)
event_df['event_id'] = event_df['event_id'].map(sym_map)

# Save events to CSV
evdf_out = "/tmp/evdf.csv"
event_df.to_csv(evdf_out, index=False)
evdf_len = len(event_df)
logging.info(f"Saved {evdf_len} events to {evdf_out}")
