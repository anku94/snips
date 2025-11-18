import logging
from bccutils.sym_mapper import SymMapper

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    ELF_PATH = "/users/ankushj/repos/orca-workspace/orca-install/lib/libmon.so"
    ELF_PATH = "/users/ankushj/repos/orca-workspace/orca-umb-install/lib/libmercury.so"
    
    mapper = SymMapper()
    mapper.add_elf(ELF_PATH, invalidate=True, prefixes=["hg_core"])
    print(f"Loaded {len(mapper._sym_to_elf)} symbols")