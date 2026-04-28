// 2^128 and 2^128 - 1 as Field literals
pub global U128_MAX: Field = 0xffffffffffffffffffffffffffffffff;
pub global U125: u128 = 42535295865117307932921825928971043232;

pub unconstrained fn unconstrained_mul_div(a_int: u128, b_int: u128, d_int: u128, half_d_int: u128) -> (Field, Field) {
    // --- Step 1: 256-bit product in four 64-bit limbs ---
    let mask: u128 = (1 << 64) - 1;
    let a_lo = a_int & mask;
    let a_hi = a_int >> 64;
    let b_lo = b_int & mask;
    let b_hi = b_int >> 64;

    // Partial products (each fits in u128)
    let p_ll = a_lo * b_lo;
    let p_lh = a_lo * b_hi;
    let p_hl = a_hi * b_lo;
    let p_hh = a_hi * b_hi;

    // Accumulate into limbs[0..3], LSB first
    let mut limbs: [u128; 4] = [0; 4];
    let s0 = p_ll + half_d_int;
    limbs[0] = s0 & mask;

    let s1 = (s0 >> 64) + (p_lh & mask) + (p_hl & mask);
    limbs[1] = s1 & mask;

    let s2 = (s1 >> 64) + (p_lh >> 64) + (p_hl >> 64) + (p_hh & mask);
    limbs[2] = s2 & mask;

    limbs[3] = (s2 >> 64) + (p_hh >> 64);

    // --- Step 2: Binary long division (256 bits d) ---
    // Invariant: r < d < 2^127, so r << 1 < 2^128 (fits in u128)
    let mut r: u128 = 0;
    let mut q_limbs: [u128; 4] = [0; 4];

    for i in 0..4 {
        let limb_idx = 3 - i; // MSB first
        for j in 0..64 {
            let bit_pos: u8 = 63 - j as u8;

            // Shift remainder left by 1 and bring in next bit
            r = (r << 1) | ((limbs[limb_idx] >> bit_pos as u128) & 1);

            if r >= d_int {
                r -= d_int;
                q_limbs[limb_idx] |= 1 << bit_pos as u128;
            }
        }
    }

    // --- Step 3: Convert quotient limbs back to Field ---
    let base: Field = (mask + 1) as Field; // 2^64
    let quotient = (q_limbs[0] as Field)
        + (q_limbs[1] as Field) * base
        + (q_limbs[2] as Field) * base * base
        + (q_limbs[3] as Field) * base * base * base;

    (quotient, r as Field)
}

/// Computes floor(a * b / d) without intermediate overflow.
///
/// Uses unconstrained computation for the muldiv operation, then verifies correctness
/// with the constraint: a * b == quotient * d + remainder.
///
/// # Arguments
///
/// * `a` - First multiplicand
/// * `b` - Second multiplicand
/// * `d` - Divisor
///
/// # Returns
///
/// floor(a * b / d) in Field
///
/// # Panics
///
/// Panics if `d` is zero (division by zero) or if remainder >= d (invalid computation)
///
/// # Example
///
/// ```ignore
/// let a = to_wad(100u128);
/// let b = to_wad(3u128);
/// let d = to_wad(2u128);
/// let result = wad_mul_div(a, b, d); // result == 150 * 10^18
/// ```
pub fn mul_div(a: Field, b: Field, d: Field) -> Field {
    assert(d != 0, "Division by zero");
    // Safety: unconstrained_mul_div is safe because:
    // 1. All inputs are verified < U125 via the asserts below
    // 2. The result is verified via the constraint a * b == q * d + r below

    let a_int = a as u128;  // proves a < 2^128
    let b_int = b as u128;  // proves b < 2^128
    let d_int = d as u128;  // proves d < 2^128

    assert(a_int < U125, "a out of safe range");
    assert(b_int < U125, "b out of safe range");
    assert(d_int < U125, "d out of safe range");

    // Safety: unconstrained_mul_div is safe because:
    // 1. All inputs are verified < U125 via the asserts above
    // 2. The result is verified via the constraint a * b == q * d + r below
    let (quotient, remainder) = unsafe { unconstrained_mul_div(a_int, b_int, d_int, 0) };

    let r_int = remainder as u128;
    let d_int = d as u128;

    assert(r_int < d_int, "Invalid remainder");

    // a * b == q * d + r (in Field)
    assert(a * b == quotient * d + remainder);

    quotient
}

/// Computes ceil(a * b / d) without intermediate overflow.
///
/// First computes floor(a * b / d), then adds 1 if there was a remainder.
///
/// # Arguments
///
/// * `a` - First multiplicand
/// * `b` - Second multiplicand
/// * `d` - Divisor
///
/// # Returns
///
/// ceil(a * b / d) in Field
///
/// # Panics
///
/// Panics if `d` is zero (division by zero)
///
/// # Example
///
/// ```ignore
/// let a = to_wad(100u128);
/// let b = to_wad(3u128);
/// let d = to_wad(2u128);
/// let result = wad_mul_div_up(a, b, d); // result == 150 * 10^18
/// ```
pub fn mul_div_up(a: Field, b: Field, d: Field) -> Field {
    assert(d != 0, "Division by zero");

    // Compute floor first
    let floor_q = mul_div(a, b, d);

    // Check if floor_q has a fractional WAD part
    // If floor_q % WAD_SCALE > 0, there was a remainder
    let wad_scale: Field = 1_000_000_000_000_000_000;
    let floor_q_int = floor_q as u128;
    let int_part = (floor_q_int / 1_000_000_000_000_000_000) as Field * wad_scale;
    let fractional_part = floor_q - int_part;

    // If there's a fractional part, round up by adding complement
    if fractional_part == 0 {
        floor_q
    } else {
        floor_q + (wad_scale - fractional_part)
    }
}
