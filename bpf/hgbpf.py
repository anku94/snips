ORCA_WS='/users/ankushj/repos/orca-workspace'

ORCA_BCC_WS=f'{ORCA_WS}/bcc-install'
ORCA_BCC_LIB=f'{ORCA_BCC_WS}/lib'

ORCA_UMB_WS=f'{ORCA_WS}/orca-umb-install'
ORCA_UMB_LIB=f'{ORCA_UMB_WS}/lib'

ORCA_MAIN_WS=f'{ORCA_WS}/orca-install'
ORCA_MAIN_LIB=f'{ORCA_MAIN_WS}/lib'

LIBHG=f'{ORCA_UMB_LIB}/libmercury.so'

import os 
import sys
from bcc import BPF, table
import bccutils as ft

# Make sure that LIBHG exists
hg_exists = os.path.exists(LIBHG)
print(f'LIBHG: {LIBHG} exists? {hg_exists}')


tracer = ft.Tracer()
spec = ft.ProbeSpec(name=LIBHG, sym="HG_Forward", uprobe=True, uretprobe=False, stack=False)
tracer.add_probe(spec)
bpf_text = tracer.gen_bpf()

print('=============')
print(bpf_text)
print('=============')

sys.exit(0)

b = BPF(text=bpf_text)
b.attach_uprobe(name=LIBHG, sym="HG_Forward", fn_name="trace_beg_21")

def callback(ctx, data, size):
    event = b["events"].event(data)
    print('----')
    print('pid', event.pid)
    print('event_id', event.event_id)
    print('tsbeg', event.tsbeg)
    # print('dura', event.dura)
    print('ret', event.ret)
    print('stack_id', event.stack_id)
    print('----')
    # pevent = ProbeEvent(event)
    # print(pevent)
    # if event.event_id == 100:
    #     print(f"PID {event.pid}: HG_Forward called at {event.tsbeg}")

b["events"].open_ring_buffer(callback)
print("Tracing HG_Forward calls...")

while True:
    b.ring_buffer_poll(1000)