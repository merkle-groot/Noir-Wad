// WAD (Wei-Agnostic Decimal) Library for Aztec
// WAD is a 18-decimal fixed-point number format

mod wad;

pub use wad::{
    fromU128, toWad, truncate, divide, add, sub, mul, mulDiv,
};
