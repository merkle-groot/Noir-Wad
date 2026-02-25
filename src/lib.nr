// WAD (Wei-Agnostic Decimal) Library for Aztec
// WAD is a 18-decimal fixed-point number format

mod wad;

pub use wad::{
    fromU128, toWad, truncate, wad_mul, add, sub, wad_div, wad_mul_div,
};
