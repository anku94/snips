from pathlib import Path
from textwrap import dedent


class TraceGen:
    """
    Generate bpftrace scripts for tracing nested functions
    using a per-thread stack emulation.
    """
    def __init__(self, max_depth: int = 8):
        """
        Initializes the generator.
        :param max_depth: The maximum nested call depth to trace.
        """
        self.probes = []
        self.max_depth = max_depth

    def add_uprobe(self, binary: str, func: str):
        """
        Add a function to be traced.
        :param binary: The absolute path to the binary or shared library.
        :param func: The mangled C++ function name.
        """
        self.probes.append((binary, func))

    def gen(self, fpath: str):
        """
        Generates the complete bpftrace script and writes it to a file.
        :param fpath: The path to write the output script to.
        """
        if not self.probes:
            Path(fpath).write_text("#!/usr/bin/env bpftrace\n\n# No probes defined.\n")
            return

        # Generate the comma-separated lists of probe points for bpftrace
        uprobe_points = ",\n".join(
            f"uprobe:{b}:{f}" for b, f in self.probes
        )
        uretprobe_points = ",\n".join(
            f"uretprobe:{b}:{f}" for b, f in self.probes
        )

        # The full script template using the correct stack-based logic
        script_body = f"""
            #define MAX_DEPTH {self.max_depth}

            BEGIN {{
                // Seems to require initialization
                // As bpftrace gets confused about its type otherwise
                @depth[0] = 0;
            }}

            // --- PUSH OPERATION: Attach to all function entries ---
            {uprobe_points}
            {{
                // Prevent stack overflow if we exceed max depth.
                if (@depth[tid] >= MAX_DEPTH) {{
                    return;
                }}

                // Get current stack pointer for this thread.
                $d = @depth[tid];

                // Push state onto our emulated stack.
                @start_ns[tid, $d] = nsecs;
                @funcname[tid, $d] = func;

                // Increment the stack pointer for the next call.
                @depth[tid]++;
            }}

            // --- POP OPERATION: Attach to all function returns ---
            {uretprobe_points}
            /@depth[tid] > 0/ // Only run if the stack for this thread is not empty.
            {{
                // Decrement stack pointer to get the index of the current frame.
                @depth[tid]--;
                $d = @depth[tid];

                // Pop state from the stack.
                $start_ns = @start_ns[tid, $d];
                $funcname = @funcname[tid, $d];

                // Record latency if we have a valid start time.
                if ($start_ns > 0) {{
                    $lat_ms = (nsecs - $start_ns) / 1000000;
                    @latms[$funcname] = hist($lat_ms);
                }}

                // Clean up the stale stack frame from the maps.
                delete(@start_ns[tid, $d]);
                delete(@funcname[tid, $d]);
            }}

            // --- REPORTING ---
            interval:s:1 {{
                print(@latms);
                clear(@latms);
            }}
        """

        # Final script assembly
        script = f"#!/usr/bin/env bpftrace\n\n{dedent(script_body)}"
        Path(fpath).write_text(script)