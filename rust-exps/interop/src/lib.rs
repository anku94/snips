// src/lib.rs
use std::os::raw::c_int;

#[repr(C)]
pub struct Point {
    x: c_int,
    y: c_int,
}

#[no_mangle]
pub extern "C" fn rust_manhattan(p: *const Point) -> f32 {
    if p.is_null() {
        println!("Received null pointer, returning 0.0");
        return 0.0;
    }
    let point = unsafe { &*p };
    println!("Received Point: x = {}, y = {}", point.x, point.y);

    let distance = ((point.x.pow(2) + point.y.pow(2)) as f32).sqrt();
    println!("Calculated distance: {}", distance);

    distance
}
