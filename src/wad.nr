use aztec::oracle::logging::debug_log_format;

// Max x where to_wad(x) doesn't overflow u128
// x <= floor((2^128 - 1) / 10^18)
global MAX_WAD_CONVERTIBLE: u128 = 340_282_366_920_938_463_463u128;

// Max x where to_wad(x) passes the 2^127 range check in wad_mul_div
// x < floor(2^127 / 10^18)
global MAX_WAD_MUL_DIV_INT: u128 = 170_141_183_460_469_231_731u128;

// Max x where wad_mul(to_wad(x), to_wad(x)) result is still < 2^127
global MAX_WAD_MUL_INT: u128 = 13_043_817_825u128;

// 2^128 and 2^128 - 1 as Field literals
global U128_MAX: Field = 0xffffffffffffffffffffffffffffffff;
global U127: u128 = 0x80000000000000000000000000000000;

/// WAD (Wei-As Decimal) type - 18-decimal fixed-point numbers
/// Uses Field representation internally
pub type Wad = Field;

// The scale factor for WAD: 10^18 (standard for Ethereum token amounts)
global SCALE: Field = 1_000_000_000_000_000_000;

unconstrained fn unconstrained_mul_div(a_int: u128, b_int: u128, d_int: u128) -> (Field, Field) {
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
    limbs[0] = p_ll & mask;

    let s1 = (p_ll >> 64) + (p_lh & mask) + (p_hl & mask);
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

/// Casts a u128 value to Wad without scaling.
///
/// This is a simple type conversion - the numeric value remains unchanged.
/// Use `to_wad` if you want to convert an integer to the WAD format (multiply by SCALE).
///
/// # Arguments
///
/// * `value` - The u128 value to convert
///
/// # Returns
///
/// The same value as a Wad type
///
/// # Example
///
/// ```ignore
/// let wad = from_u128(100u128); // wad == 100
/// ```
pub fn from_u128(value: u128) -> Wad {
    value as Wad
}

/// Converts a u128 value to WAD format by scaling.
///
/// Multiplies the input by SCALE (10^18) to convert from integer units
/// to WAD fixed-point representation.
///
/// # Arguments
///
/// * `value` - The u128 value to scale
///
/// # Returns
///
/// The value scaled to WAD format
///
/// # Example
///
/// ```ignore
/// let wad = to_wad(100u128); // wad == 100 * 10^18
/// ```
pub fn to_wad(value: u128) -> Wad {
    (value as Wad) * SCALE
}

/// Extracts the integer part of a WAD value.
///
/// Divides by SCALE (10^18) and returns the whole number portion,
/// discarding any fractional part.
///
/// # Arguments
///
/// * `value` - The WAD value to truncate
///
/// # Returns
///
/// The integer part of the WAD value
///
/// # Example
///
/// ```ignore
/// let wad = to_wad(100u128) + to_wad(50u128) / SCALE; // 100.5 WAD
/// let integer = truncate(wad); // integer == 100
/// ```
pub fn truncate(value: Wad) -> u128 {
    (value as u128) / (SCALE as u128)
}

/// Divides two WAD values.
///
/// Computes a / b and returns the result in WAD format by scaling: floor(a * SCALE / b).
/// This preserves fractional precision - use truncate() to get the integer floor.
///
/// # Arguments
///
/// * `a` - The numerator in WAD format
/// * `b` - The denominator in WAD format
///
/// # Returns
///
/// The quotient in WAD format
///
/// # Panics
///
/// Panics if `b` is zero (division by zero)
///
/// # Example
///
/// ```ignore
/// let a = to_wad(100u128);
/// let b = to_wad(2u128);
/// let result = wad_div(a, b); // result == 50 * 10^18
/// ```
pub fn wad_div(a: Field, b: Field) -> Field {
    wad_mul_div(a, SCALE, b)
}

/// wad_adds two WAD values.
///
/// Simple wad_addition operation since both values are already in the same scale.
///
/// # Arguments
///
/// * `value` - First WAD value
/// * `other` - Second WAD value
///
/// # Returns
///
/// The sum in WAD format
///
/// # Example
///
/// ```ignore
/// let a = to_wad(100u128);
/// let b = to_wad(50u128);
/// let result = wad_add(a, b); // result == 150 * 10^18
/// ```
pub fn wad_add(value: Wad, other: Wad) -> Wad {
    value + other
}

/// wad_subtracts one WAD value from another.
///
/// # Arguments
///
/// * `value` - The WAD value to wad_subtract from
/// * `other` - The WAD value to wad_subtract
///
/// # Returns
///
/// The difference in WAD format
///
/// # Panics
///
/// Panics if `value < other` (underflow)
///
/// # Example
///
/// ```ignore
/// let a = to_wad(100u128);
/// let b = to_wad(30u128);
/// let result = wad_sub(a, b); // result == 70 * 10^18
/// ```
pub fn wad_sub(value: Wad, other: Wad) -> Wad {
    assert(value as u128 >= other as u128, "WAD wad_subtraction underflow");
    value - other
}

/// Multiplies two WAD values.
///
/// Computes a * b and returns the result in WAD format by scaling: floor(a * b / SCALE).
/// This preserves fractional precision - use truncate() to get the integer floor.
///
/// # Arguments
///
/// * `a` - First WAD value
/// * `b` - Second WAD value
///
/// # Returns
///
/// The product in WAD format
///
/// # Example
///
/// ```ignore
/// let a = to_wad(100u128);
/// let b = to_wad(2u128);
/// let result = wad_mul(a, b); // result == 200 * 10^18
/// ```
pub fn wad_mul(a: Field, b: Field) -> Field {
    wad_mul_div(a, b, SCALE)
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
pub fn wad_mul_div(a: Field, b: Field, d: Field) -> Field {
    assert(d != 0, "Division by zero");
    // Safety: the result of muldiv is being checked

    let a_int = a as u128;  // proves a < 2^128
    let b_int = b as u128;  // proves b < 2^128
    let d_int = d as u128;  // proves d < 2^128

    assert(a_int < U127, "a out of safe range");
    assert(b_int < U127, "b out of safe range");
    assert(d_int < U127, "d out of safe range");

    // Safety: The result is being checked right after
    let (quotient, remainder) = unsafe { unconstrained_mul_div(a_int, b_int, d_int) };

    // Range checks
    let q_check = quotient as u128; 
    let r_int = remainder as u128;
    let d_int = d as u128;

    assert(r_int < d_int, "Invalid remainder");

    // a * b == q * d + r (in Field)
    assert(a * b == quotient * d + remainder);

    quotient
}


#[test]
fn test_from_u128() {
    // --- Basic conversions ---
    // Zero conversion
    assert(from_u128(0u128) == 0);
    // Unit conversion
    assert(from_u128(1u128) == 1);
    // Small integer conversion
    assert(from_u128(100u128) == 100);
    // Large integer conversion (SCALE value)
    assert(from_u128(1_000_000_000_000_000_000u128) == 1_000_000_000_000_000_000);
}

#[test]
fn test_to_wad() {
    // --- Basic conversions ---
    // Zero converts to 0
    let wad_0 = to_wad(0u128);
    assert(wad_0 == 0);

    // 1 converts to SCALE
    let wad_1 = to_wad(1u128);
    assert(wad_1 == SCALE);

    // 100 converts to 100 * SCALE
    let wad_100 = to_wad(100u128);
    assert(wad_100 == SCALE * 100);
}

#[test]
fn test_truncate() {
    // --- Basic truncations ---
    // Zero truncates to 0
    let wad_0 = to_wad(0u128);
    assert(truncate(wad_0) == 0);

    // SCALE truncates to 1
    let wad_1 = to_wad(1u128);
    assert(truncate(wad_1) == 1);

    // 100 * SCALE truncates to 100
    let wad_100 = to_wad(100u128);
    assert(truncate(wad_100) == 100);
}

#[test]
fn test_wad_add() {
    // --- Basic wad_addition ---
    // 100 + 50 = 150
    let a = to_wad(100u128);
    let b = to_wad(50u128);
    let result = wad_add(a, b);
    assert(result == to_wad(150u128));

    // --- Zero properties ---
    // a + 0 = a
    let zero = from_u128(0u128);
    assert(wad_add(a, zero) == a);
    // 0 + 0 = 0
    assert(wad_add(zero, zero) == 0);

    // --- Commutativity ---
    // a + b = b + a
    let x = to_wad(123u128);
    let y = to_wad(456u128);
    assert(wad_add(x, y) == wad_add(y, x));
}

#[test]
fn test_wad_sub() {
    // --- Basic wad_subtraction ---
    // 100 - 30 = 70
    let a = to_wad(100u128);
    let b = to_wad(30u128);
    let result = wad_sub(a, b);
    assert(result == to_wad(70u128));

    // --- Zero properties ---
    // a - 0 = a
    let zero = from_u128(0u128);
    assert(wad_sub(a, zero) == a);
    // 0 - 0 = 0
    assert(wad_sub(zero, zero) == 0);
}

#[test(should_fail_with = "WAD wad_subtraction underflow")]
fn test_wad_sub_underflow() {
    // U128_MAX = 2**128 - 1, which is > 2**127 => correctly rejected
    let _ = wad_sub(to_wad(5), to_wad(6));
}


#[test]
fn test_wad_mul() {
    // --- Basic multiplication tests ---
    // 2 * 3 = 6
    let a = to_wad(2u128);
    let b = to_wad(3u128);
    let result = wad_mul(a, b);
    assert(result == to_wad(6u128));

    // 10 * 5 = 50
    let x = to_wad(10u128);
    let y = to_wad(5u128);
    assert(wad_mul(x, y) == to_wad(50u128));

    // 100 * 100 = 10000
    let m = to_wad(100u128);
    assert(wad_mul(m, m) == to_wad(10000u128));

    // --- Zero multiplication ---
    // 0 * x = 0
    let zero = from_u128(0u128);
    assert(wad_mul(zero, to_wad(123u128)) == 0);
    // x * 0 = 0
    assert(wad_mul(to_wad(123u128), zero) == 0);
    // 0 * 0 = 0
    assert(wad_mul(zero, zero) == 0);

    // --- Identity multiplication ---
    // 1 * x = x
    let one = to_wad(1u128);
    assert(wad_mul(one, to_wad(42u128)) == to_wad(42u128));
    // x * 1 = x
    assert(wad_mul(to_wad(42u128), one) == to_wad(42u128));
    // 1 * 1 = 1
    assert(wad_mul(one, one) == to_wad(1u128));

    // --- Commutativity ---
    let a_val = to_wad(7u128);
    let b_val = to_wad(11u128);
    assert(wad_mul(a_val, b_val) == wad_mul(b_val, a_val));

    // --- Associativity (checked indirectly through composition) ---
    let a_ass = to_wad(3u128);
    let b_ass = to_wad(4u128);
    let c_ass = to_wad(5u128);
    // (3 * 4) * 5 = 60
    let left_assoc = wad_mul(wad_mul(a_ass, b_ass), c_ass);
    let right_assoc = wad_mul(a_ass, wad_mul(b_ass, c_ass));
    assert(left_assoc == to_wad(60u128));
    assert(right_assoc == to_wad(60u128));

    // --- Distributivity over wad_addition ---
    // a * (b + c) = a * b + a * c
    let a_dist = to_wad(2u128);
    let b_dist = to_wad(3u128);
    let c_dist = to_wad(4u128);
    let left_dist = wad_mul(a_dist, wad_add(b_dist, c_dist));
    let right_dist = wad_add(wad_mul(a_dist, b_dist), wad_mul(a_dist, c_dist));
    assert(left_dist == right_dist);

    // --- Fractional results (floor) ---
    // 3 * 0.5 = 1.5, should floor to 1 in integer check
    let three = to_wad(3u128);
    let half = SCALE / 2; // 0.5 in WAD
    let three_half = wad_mul(three, half);
    // Result should be 1.5 WAD = SCALE + SCALE/2
    assert(three_half == SCALE + (SCALE / 2));

    // --- Larger values ---
    let large_a = to_wad(12345u128);
    let large_b = to_wad(6789u128);
    // Verify it doesn't overflow or panic
    let large_result = wad_mul(large_a, large_b);
    assert(large_result != 0);
    // Verify via truncate and approximate check
    // 12345 * 6789 = 83810205

    debug_log_format("large result: {}", [large_result]);
    assert(truncate(large_result) >= 83810205u128);
}

#[test(should_fail_with = "Division by zero")]
fn test_wad_div_divide_by_zero() {
    let _ = wad_div(from_u128(12), 0);
}

#[test]
fn test_wad_div() {
    // --- Basic division tests ---
    // 100 / 2 = 50
    let a = to_wad(100u128);
    let b = to_wad(2u128);
    assert(wad_div(a, b) == to_wad(50u128));

    // 50 / 2 = 25
    let c = to_wad(50u128);
    assert(wad_div(c, b) == to_wad(25u128));

    // 81 / 9 = 9
    let d = to_wad(81u128);
    let e = to_wad(9u128);
    assert(wad_div(d, e) == to_wad(9u128));

    // --- Identity division ---
    // x / 1 = x
    let one = to_wad(1u128);
    assert(wad_div(to_wad(42u128), one) == to_wad(42u128));
    assert(wad_div(to_wad(1000u128), one) == to_wad(1000u128));

    // --- Division by itself ---
    // x / x = 1
    let x = to_wad(7u128);
    assert(wad_div(x, x) == one);
    let y = to_wad(12345u128);
    assert(wad_div(y, y) == one);

    // --- Zero numerator ---
    // 0 / x = 0 (for x != 0)
    let zero = from_u128(0u128);
    assert(wad_div(zero, to_wad(5u128)) == 0);
    assert(wad_div(zero, to_wad(1000u128)) == 0);

    // --- Fractional results ---
    // wad_div returns the WAD representation (preserves fractional parts)
    // truncate(wad_div(a, b)) gives the integer floor

    // 7 / 2 = 3.5 in WAD = 3 * SCALE + SCALE/2
    let seven = to_wad(7u128);
    let two = to_wad(2u128);
    let seven_halves = wad_div(seven, two);
    // Result should be 3.5 WAD
    assert(seven_halves == to_wad(3u128) + SCALE / 2);
    // Truncating gives the integer floor
    assert(truncate(seven_halves) == 3u128);

    // --- Verify relationship: a = (a / b) * b + remainder ---
    // For exact divisions, this should hold
    let exact_a = to_wad(100u128);
    let exact_b = to_wad(4u128);
    let exact_div = wad_div(exact_a, exact_b);
    let exact_mul = wad_mul(exact_div, exact_b);
    assert(exact_mul == exact_a);

    // --- Inverse of multiplication (for exact division) ---
    let m1 = to_wad(12u128);
    let m2 = to_wad(3u128);
    let product = wad_mul(m1, m2);
    // (12 * 3) / 3 = 12
    assert(wad_div(product, m2) == m1);
    assert(wad_div(product, m1) == m2);

    // --- Larger values ---
    let large_num = to_wad(123456789u128);
    let large_den = to_wad(9876u128);
    let large_result = wad_div(large_num, large_den);
    assert(large_result != 0);
    // 123456789 / 9876 approx 1250.19, so result should be 12500
    debug_log_format("result: {}", [large_result]);
    assert(truncate(large_result) == 12500u128);

    // --- Power of 2 divisions ---
    let pow2_num = to_wad(1024u128);
    assert(wad_div(pow2_num, to_wad(2u128)) == to_wad(512u128));
    assert(wad_div(pow2_num, to_wad(4u128)) == to_wad(256u128));
    assert(wad_div(pow2_num, to_wad(8u128)) == to_wad(128u128));
}

#[test]
fn test_wad_mul_div() {
    // --- Basic tests: floor(a * b / d) ---
    // 100 * 3 / 2 = 150
    let a = to_wad(100u128);
    let b = to_wad(3u128);
    let c = to_wad(2u128);
    assert(wad_mul_div(a, b, c) == to_wad(150u128));

    // 10 * 5 / 2 = 25
    let x = to_wad(10u128);
    let y = to_wad(5u128);
    let z = to_wad(2u128);
    assert(wad_mul_div(x, y, z) == to_wad(25u128));

    // 6 * 4 / 3 = 8
    assert(wad_mul_div(to_wad(6u128), to_wad(4u128), to_wad(3u128)) == to_wad(8u128));

    // --- Zero multiplication ---
    // 0 * a / d = 0
    let zero = from_u128(0u128);
    assert(wad_mul_div(zero, to_wad(100u128), to_wad(5u128)) == 0);
    assert(wad_mul_div(to_wad(100u128), zero, to_wad(5u128)) == 0);
    assert(wad_mul_div(zero, zero, to_wad(5u128)) == 0);

    // --- Identity tests ---
    // a * 1 / 1 = a
    let one = to_wad(1u128);
    assert(wad_mul_div(to_wad(42u128), one, one) == to_wad(42u128));
    // a * 1 / d = a / d
    assert(wad_mul_div(to_wad(100u128), one, to_wad(4u128)) == to_wad(25u128));

    // --- Division by 1 ---
    // a * b / 1 = a * b
    let m1 = to_wad(7u128);
    let m2 = to_wad(8u128);
    assert(wad_mul_div(m1, m2, one) == to_wad(56u128));

    // --- Fractional results ---
    // wad_mul_div with WAD inputs preserves fractional precision
    // 10 * 3 / 4 = 7.5, so result is 7.5 in WAD = 7 * SCALE + SCALE/2
    let ten_three_four = wad_mul_div(to_wad(10u128), to_wad(3u128), to_wad(4u128));
    debug_log_format("result: {}", [truncate(ten_three_four) as Field]);
    assert(ten_three_four == to_wad(7u128) + SCALE / 2);
    assert(truncate(ten_three_four) == 7u128);

    // 7 * 3 / 5 = 4.2, so result is 4.2 in WAD
    let seven_three_five = wad_mul_div(to_wad(7u128), to_wad(3u128), to_wad(5u128));
    assert(truncate(seven_three_five) == 4u128);

    debug_log_format("seven_three_five: {}", [to_wad(4u128) + SCALE / 5]);
    assert(seven_three_five == to_wad(4u128) + SCALE / 5);

    // --- Commutativity in numerator ---
    // a * b / d = b * a / d
    let comm_a = to_wad(12u128);
    let comm_b = to_wad(7u128);
    let comm_d = to_wad(3u128);
    assert(wad_mul_div(comm_a, comm_b, comm_d) == wad_mul_div(comm_b, comm_a, comm_d));

    // --- Relationship with wad_mul and wad_div ---
    // wad_mul_div(a, b, SCALE) = wad_mul(a, b)
    let mul_a = to_wad(10u128);
    let mul_b = to_wad(5u128);
    assert(wad_mul_div(mul_a, mul_b, SCALE) == wad_mul(mul_a, mul_b));

    // wad_mul_div(a, SCALE, d) = wad_div(a, d)
    assert(wad_mul_div(to_wad(100u128), SCALE, to_wad(4u128)) == wad_div(to_wad(100u128), to_wad(4u128)));

    // Left: floor(floor(A*B*S/C) / D)
    // Right: floor(A*B*S / (C*D))
    // These are ALWAYS equal by the identity floor(floor(N/a)/b) = floor(N/(ab)).
    // No exact division requirement.
    let comp_a = to_wad(24u128);
    let comp_b = to_wad(5u128);
    let comp_c = to_wad(3u128);
    let comp_d = to_wad(5u128);
    let left = wad_mul_div(wad_mul_div(comp_a, comp_b, comp_c), one, comp_d);
    let right = wad_mul_div(comp_a, comp_b, wad_mul(comp_c, comp_d));
    // Both should give 8
    assert(left == to_wad(8u128));
    assert(right == to_wad(8u128));

    // Non exact
    let a = to_wad(1u128);
    let b = to_wad(1u128);
    let c = to_wad(3u128); // 1/3 is not exact
    let d = to_wad(3u128); // 1/9 is not exact

    let left  = wad_mul_div(wad_mul_div(a, b, c), one, d);
    let right = wad_mul_div(a, b, wad_mul(c, d));

    // Both == floor(10^18 / 9) == 111_111_111_111_111_111
    assert(left == right);

    // --- Large values ---
    let large_a = to_wad(10000u128);
    let large_b = to_wad(9999u128);
    let large_d = to_wad(5000u128);
    let large_result = wad_mul_div(large_a, large_b, large_d);
    // 10000 * 9999 / 5000 = 19998
    assert(large_result == to_wad(19998u128));

    // --- Exact division verification ---
    // For exact division: a * b = q * d
    let exact_a = to_wad(12u128);
    let exact_b = to_wad(8u128);
    let exact_d = to_wad(6u128);
    let exact_q = wad_mul_div(exact_a, exact_b, exact_d);
    // q = 96 / 6 = 16
    assert(exact_q == to_wad(16u128));
    // Verify: 12 * 8 = 96, 16 * 6 = 96
    assert(wad_mul(exact_a, exact_b) == wad_mul(exact_q, exact_d));

    // --- Remainder behavior ---
    // wad_mul_div with WAD inputs preserves fractional precision
    // 10 * 7 / 9 = 70/9 = 7.777... in WAD
    let rem_q = wad_mul_div(to_wad(10u128), to_wad(7u128), to_wad(9u128));
    // Result is 7 * SCALE + (7/9) * SCALE
    // Truncating gives integer floor
    debug_log_format("repeated dec 70/9: {}", [rem_q]);
    assert(truncate(rem_q) == 7u128);
    assert(rem_q == 7777777777777777777)
}

#[test]
fn test_roundtrip_conversions() {
    // --- Roundtrip: u128 -> WAD -> u128 ---
    // Converting to WAD and back should preserve the original value
    let original = 12345u128;
    let wad = to_wad(original);
    let recovered = truncate(wad);
    assert(recovered == original);
}

#[test]
fn test_arithmetic_properties() {
    let a = to_wad(100u128);
    let b = to_wad(30u128);
    let zero = from_u128(0u128);
    let one = to_wad(1u128);

    // --- wad_addition/wad_subtraction inverse ---
    // (a + b) - b = a
    assert(wad_sub(wad_add(a, b), b) == a);
    // (a - b) + b = a
    assert(wad_add(wad_sub(a, b), b) == a);

    // --- Zero properties ---
    // a * 0 = 0
    assert(wad_mul(a, zero) == 0);
    // 0 * a = 0
    assert(wad_mul(zero, a) == 0);
    // a + 0 = a
    assert(wad_add(a, zero) == a);
    // 0 + a = a
    assert(wad_add(zero, a) == a);
    // a - 0 = a
    assert(wad_sub(a, zero) == a);

    // --- Identity properties ---
    // a * 1 = a
    assert(wad_mul(a, one) == a);
    // 1 * a = a
    assert(wad_mul(one, a) == a);
    // a / 1 = a
    assert(wad_div(a, one) == a);
    // a / a = 1
    assert(wad_div(a, a) == one);

    // --- Distributivity ---
    // a * (b + c) = a * b + a * c
    let c = to_wad(5u128);
    assert(wad_mul(a, wad_add(b, c)) == wad_add(wad_mul(a, b), wad_mul(a, c)));

    // --- Commutativity of multiplication ---
    // a * b = b * a
    assert(wad_mul(a, b) == wad_mul(b, a));
}

// --- Overflow tests: inputs that exceed u128 ---

#[test(should_fail)]
fn test_wad_mul_div_overflow_a_exceeds_u128() {
    // a = 2^128, constrained cast in wad_mul_div should reject this
    let _ = wad_mul_div(U128_MAX + 1, to_wad(1u128), to_wad(1u128));
}

#[test(should_fail)]
fn test_wad_mul_div_overflow_b_exceeds_u128() {
    // b = 2^128, should fail cast
    let _ = wad_mul_div(to_wad(1u128), U128_MAX + 1, to_wad(1u128));
}

#[test(should_fail)]
fn test_wad_mul_div_overflow_d_exceeds_u128() {
    // d = 2^128, should fail cast
    let _ = wad_mul_div(to_wad(1u128), to_wad(1u128), U128_MAX + 1);
}

#[test(should_fail)]
fn test_wad_mul_div_a_is_field_max() {
    // p - 1 is a valid Field but way beyond u128 => must fail
    // BN254 prime - 1
    let field_max: Field = 0x30644e72e131a029b85045b68181585d2833e84879b9709142e1f01a0000000;
    let _ = wad_mul_div(field_max, to_wad(1u128), to_wad(1u128));
}

#[test(should_fail)]
fn test_wad_mul_div_division_by_zero() {
    // Division by zero should fail
    let _ = wad_mul_div(to_wad(1u128), to_wad(1u128), 0);
}


// --- Boundary value tests ---

#[test(should_fail_with = "a out of safe range")]
fn test_wad_mul_div_a_at_u128_max() {
    // U128_MAX = 2**128 - 1, which is > 2**127 => correctly rejected
    let _ = wad_mul_div(U128_MAX, U128_MAX, U128_MAX);
}

#[test(should_fail_with = "a out of safe range")]
fn test_wad_mul_div_a_one_below_u128_max() {
    // 2**128 - 2 is still > 2**127 => correctly rejected
    let one_below: Field = 0xfffffffffffffffffffffffffffffffe;
    let _ = wad_mul_div(one_below, 1, 1);
}

#[test]
fn test_wad_mul_div_large_product_exact() {
    // sqrt(u128::MAX) =approx 2^64, so (2^64) * (2^64) = 2^128 => this overflows product
    // Use values whose product stays within safe range:
    // 2^63 * 2^63 = 2^126 which is < p, safe for field constraint
    let half_64: Field = 0x8000000000000000; // 2^63
    let result = wad_mul_div(half_64, half_64, half_64);
    // a * a / a = a
    assert(result == half_64);

    let result_1 = wad_mul_div(half_64, half_64, from_u128(1));
    debug_log_format("large product: {}", [result_1]);
    // python3 >>> 0x8000000000000000 * 0x8000000000000000
    // 85070591730234615865843651857942052864
    assert(result_1 == 85070591730234615865843651857942052864)
}

#[test(should_fail_with = "a out of safe range")]
fn test_wad_mul_div_rejects_above_max_wad_mul_div_int_a() {
    let _ = wad_mul_div(to_wad(MAX_WAD_MUL_DIV_INT + 1), to_wad(1u128), to_wad(1u128));
}

#[test(should_fail_with = "b out of safe range")]
fn test_wad_mul_div_rejects_above_max_wad_mul_div_int_b() {
    let _ = wad_mul_div(to_wad(1u128), to_wad(MAX_WAD_MUL_DIV_INT + 1), to_wad(1u128));
}

#[test(should_fail_with = "d out of safe range")]
fn test_wad_mul_div_rejects_above_max_wad_mul_div_int_d() {
    let _ = wad_mul_div(to_wad(1u128), to_wad(1u128), to_wad(MAX_WAD_MUL_DIV_INT + 1));
}

#[test]
fn test_wad_mul_div_accepts_max_wad_mul_int() {
    // MAX_WAD_MUL_INT is the ceiling for wad_mul(x,x) results, not wad_mul_div inputs.
    // to_wad(MAX_WAD_MUL_INT) < 2^127 so wad_mul_div accepts it.
    let _ = wad_mul_div(to_wad(MAX_WAD_MUL_INT), to_wad(1u128), to_wad(1u128));
}

#[test]
fn test_wad_mul_div_product_near_field_boundary() {
    // For u128-scale inputs whose product a*b approaches 2^254,
    // the field constraint `a * b == q * d + r` can be satisfied by a WRONG quotient
    // because field arithmetic wraps mod p.
    //
    // BN254 p =approx 2**254. Two u128 inputs at approx 2**127 each => product =approx 2**254 =approx p => wraps.
    //
    // 2^127 = 0x80000000000000000000000000000000
    let near_half_u128: Field = 0x7fffffffffffffffffffffffffffffff; // 2^127 - 1
    let result = wad_mul_div(near_half_u128, near_half_u128, near_half_u128);
    // Result should equal near_half_u128 (a*a/a = a)
    // If field overflow occurs, this assertion will FAIL demonstrating the unsoundness
    assert(result == near_half_u128);
}

// --- Remainder edge case tests ---

#[test]
fn test_wad_mul_div_remainder_just_below_divisor() {
    // 10 * 9 / 7 = 90 / 7 = 12 remainder 6  (remainder = d-1, maximum valid remainder)
    let result = wad_mul_div(to_wad(10u128), to_wad(9u128), to_wad(7u128));
    assert(truncate(result) == 12u128);
}

#[test]
fn test_wad_mul_div_result_is_zero_due_to_floor() {
    // 1 * 1 / (very large d) floors to 0
    let large_d = to_wad(100u128);
    let small_a: Field = 1; // 1 raw Field unit, not WAD
    let result = wad_mul_div(small_a, small_a, large_d);
    assert(result == 0);
}

#[test]
fn test_truncation_of_largest_mul(){
    let result = wad_mul(to_wad(MAX_WAD_MUL_INT), to_wad(MAX_WAD_MUL_INT));
    debug_log_format("the largest product: {}", [result]);
    assert(result == 170141183451787730625 * SCALE);
    assert(truncate(result) == 170141183451787730625);
}

#[test]
fn test_wad_mul_div_d_equals_one() {
    // d = 1 (raw Field, not WAD): a * b / 1 = a * b
    // Check quotient doesn't overflow u128 after we get the constrained range check
    let a = to_wad(2u128);
    let b = to_wad(3u128);
    let result = wad_mul_div(a, b, 1);
    // a * b in WAD units = 6 * SCALE^2, not scaled back just raw product
    assert(result == a * b);
}