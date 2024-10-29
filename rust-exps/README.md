## Interop
Example of cpp code calling rust code, both mixed in the same source directories.

Header files for the cpp project are generated manually.

## Interop-2
Example of cpp code calling rust code, Rust in a self-contained directory

Header files for the cpp project are generated automatically by the `cbindgen` tool.

## Other Approaches
- Use `cmake-rs` (https://github.com/rust-lang/cmake-rs)
- Use `corrosion` (https://github.com/corrosion-rs/corrosion)
