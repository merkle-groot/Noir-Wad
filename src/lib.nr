// WAD (Wei-Agnostic Decimal) Library for Aztec
// WAD is a 18-decimal fixed-point number format

mod wad;
mod common;
mod ray;
mod percentMath;
mod utilities;

pub use wad::{
    from_u128,
    to_wad,
    truncate,
    wad_mul,
    wad_mul_up,
    wad_add,
    wad_sub,
    wad_div,
    wad_div_up,
    wad_mul_div,
    wad_mul_div_up,
    MAX_WAD_CONVERTIBLE,
    MAX_WAD_MUL_DIV_INT,
    MAX_WAD_MUL_INT
};

pub use ray::{
    to_ray,
    ray_mul,
    ray_mul_up,
    ray_add,
    ray_sub,
    ray_div,
    ray_div_up,
    ray_mul_div,
    ray_mul_div_up,
    MAX_RAY_CONVERTIBLE,
    MAX_RAY_MUL_DIV_INT,
    MAX_RAY_MUL_INT
};
