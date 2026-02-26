// WAD (Wei-Agnostic Decimal) Library for Aztec
// WAD is a 18-decimal fixed-point number format

mod wad;

pub use wad::{
    from_u128, to_wad, truncate, wad_mul, wad_add, wad_sub, wad_div, wad_mul_div,
};
