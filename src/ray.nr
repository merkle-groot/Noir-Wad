use aztec::oracle::logging::debug_log_format;
use crate::common::{
    mul_div_up,
    mul_div,
    U128_MAX
};

// Max x where to_ray(x) doesn't overflow u128
// x <= floor((2^128 - 1) / 10^27)
pub global MAX_RAY_CONVERTIBLE: u128 = 340_282_366_920u128;

// Max x where to_ray(x) passes 2^125 range check in ray_mul_div
// x < floor(2^125 / 10^27)
pub global MAX_RAY_MUL_DIV_INT: u128 = 42_535_295_865u128;

// Max x where ray_mul(to_ray(x), to_ray(x)) result is still < 2^125
pub global MAX_RAY_MUL_INT: u128 = 206_240u128;

/// RAY type - 27-decimal fixed-point numbers
/// Uses Field representation internally
pub type Ray = Field;

// The scale factor for RAY: 10^27
global RAY_SCALE: Field = 1_000_000_000_000_000_000_000_000_000;

/// Casts a u128 value to Ray without scaling.
///
/// This is a simple type conversion - the numeric value remains unchanged.
/// Use `to_ray` if you want to convert an integer to the RAY type with scaling.
///
/// # Arguments
///
/// * `value` - The u128 value to convert
///
/// # Returns
///
/// The same value as a Ray type
///
/// # Example
///
/// ```ignore
/// let ray = from_u128(100u128); // ray == 100
/// ```
pub fn from_u128(value: u128) -> Ray {
    value as Ray
}

/// Converts a u128 value to Ray format by scaling.
///
/// Multiplies the input by RAY_SCALE (10^27) to convert from integer units
/// to RAY fixed-point representation.
///
/// # Arguments
///
/// * `value` - The u128 value to scale
///
/// # Returns
///
/// The value scaled to RAY format
///
/// # Example
///
/// ```ignore
/// let ray = to_ray(100u128); // ray == 100 * 10^27
/// ```
pub fn to_ray(value: u128) -> Ray {
    (value as Ray) * RAY_SCALE
}

/// Extracts the integer part of a Ray value.
///
/// Divides by RAY_SCALE (10^27) and returns the whole number portion,
/// discarding any fractional part.
///
/// # Arguments
///
/// * `value` - The RAY value to truncate
///
/// # Returns
///
/// The integer part of the Ray value
///
/// # Example
///
/// ```ignore
/// let ray = to_ray(100u128) + to_ray(5u128) / RAY_SCALE; // 100.5 RAY
/// let integer = truncate(ray); // integer == 100
/// ```
pub fn truncate(value: Ray) -> u128 {
    (value as u128) / (RAY_SCALE as u128)
}

/// Divides two RAY values.
///
/// Computes a / b and returns the result in RAY format by scaling: floor(a * RAY_SCALE / b).
/// This preserves fractional precision - use truncate() to get the integer floor.
///
/// # Arguments
///
/// * `a` - The numerator in RAY format
/// * `b` - The denominator in RAY format
///
/// # Returns
///
/// The quotient in RAY format
///
/// # Panics
///
/// Panics if `b` is zero (division by zero)
///
/// # Example
///
/// ```ignore
/// let a = to_ray(100u128);
/// let b = to_ray(2u128);
/// let result = ray_div(a, b); // result == 50 * 10^27
/// ```
pub fn ray_div(a: Field, b: Field) -> Field {
    ray_mul_div(a, RAY_SCALE, b)
}

/// Divides two RAY values with rounding up.
///
/// Computes ceil(a / b) and returns the result in RAY format by scaling: ceil(a * RAY_SCALE / b).
/// This preserves fractional precision and rounds up to the nearest unit.
///
/// # Arguments
///
/// * `a` - The numerator in RAY format
/// * `b` - The denominator in RAY format
///
/// # Returns
///
/// The quotient in RAY format, rounded up
///
/// # Panics
///
/// Panics if `b` is zero (division by zero)
///
/// # Example
///
/// ```ignore
/// let a = to_ray(100u128);
/// let b = to_ray(2u128);
/// let result = ray_div_up(a, b); // result == 50 * 10^27
/// ```
pub fn ray_div_up(a: Field, b: Field) -> Field {
    ray_mul_div_up(a, RAY_SCALE, b)
}

/// Adds two RAY values.
///
/// Simple addition operation since both values are already in the same scale.
///
/// # Arguments
///
/// * `value` - First RAY value
/// * `other` - Second RAY value
///
/// # Returns
///
/// The sum in RAY format
///
/// # Example
///
/// ```ignore
/// let a = to_ray(100u128);
/// let b = to_ray(50u128);
/// let result = ray_add(a, b); // result == 150 * 10^27
/// ```
pub fn ray_add(value: Ray, other: Ray) -> Ray {
    value + other
}

/// Subtracts one RAY value from another.
///
/// # Arguments
///
/// * `value` - The RAY value to subtract from
/// * `other` - The RAY value to subtract
///
/// # Returns
///
/// The difference in RAY format
///
/// # Panics
///
/// Panics if `value < other` (underflow)
///
/// # Example
///
/// ```ignore
/// let a = to_ray(100u128);
/// let b = to_ray(30u128);
/// let result = ray_sub(a, b); // result == 70 * 10^27
/// ```
pub fn ray_sub(value: Ray, other: Ray) -> Ray {
    assert(value as u128 >= other as u128, "RAY subtraction underflow");
    value - other
}

/// Multiplies two RAY values.
///
/// Computes a * b and returns the result in RAY format by scaling: floor(a * b / RAY_SCALE).
/// This preserves fractional precision - use truncate() to get the integer floor.
///
/// # Arguments
///
/// * `a` - First RAY value
/// * `b` - Second RAY value
///
/// # Returns
///
/// The product in RAY format
///
/// # Example
///
/// ```ignore
/// let a = to_ray(100u128);
/// let b = to_ray(2u128);
/// let result = ray_mul(a, b); // result == 200 * 10^27
/// ```
pub fn ray_mul(a: Field, b: Field) -> Field {
    ray_mul_div(a, b, RAY_SCALE)
}

/// Multiplies two RAY values with rounding up.
///
/// Computes ceil(a * b) and returns the result in RAY format by scaling: ceil(a * b / RAY_SCALE).
/// This preserves fractional precision and rounds up to the nearest unit.
///
/// # Arguments
///
/// * `a` - First RAY value
/// * `b` - Second RAY value
///
/// # Returns
///
/// The product in RAY format, rounded up
///
/// # Example
///
/// ```ignore
/// let a = to_ray(100u128);
/// let b = to_ray(2u128);
/// let result = ray_mul_up(a, b); // result == 200 * 10^27
/// ```
pub fn ray_mul_up(a: Field, b: Field) -> Field {
    ray_mul_div_up(a, b, RAY_SCALE)
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
/// let a = to_ray(100u128);
/// let b = to_ray(3u128);
/// let d = to_ray(2u128);
/// let result = ray_mul_div(a, b, d); // result == 150 * 10^27
/// ```
pub fn ray_mul_div(a: Field, b: Field, d: Field) -> Field {
    mul_div(a, b, d)
}

/// Computes ceil(a * b / d) without intermediate overflow.
///
/// Uses unconstrained computation for the muldiv operation, then verifies correctness
/// with the constraint: a * b + d/2 == quotient * d + remainder.
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
/// Panics if `d` is zero (division by zero) or if remainder >= d (invalid computation)
///
/// # Example
///
/// ```ignore
/// let a = to_ray(100u128);
/// let b = to_ray(3u128);
/// let d = to_ray(2u128);
/// let result = ray_mul_div_up(a, b, d); // result == 150 * 10^27
/// ```
pub fn ray_mul_div_up(a: Field, b: Field, d: Field) -> Field {
    mul_div_up(a, b, d)
}

#[test]
fn test_from_u128() {
    // Zero conversion
    assert(from_u128(0u128) == 0);
    // Unit conversion
    assert(from_u128(1u128) == 1);
    // Small integer conversion
    assert(from_u128(100u128) == 100);
}

#[test]
fn test_to_ray() {
    // Zero converts to 0
    let ray_0 = to_ray(0u128);
    assert(ray_0 == 0);

    // 1 converts to RAY_SCALE
    let ray_1 = to_ray(1u128);
    assert(ray_1 == RAY_SCALE);

    // 100 converts to 100 * RAY_SCALE
    let ray_100 = to_ray(100u128);
    assert(ray_100 == RAY_SCALE * 100);
}

#[test]
fn test_truncate() {
    // Zero truncates to 0
    let ray_0 = to_ray(0u128);
    assert(truncate(ray_0) == 0);

    // RAY_SCALE truncates to 1
    let ray_1 = to_ray(1u128);
    assert(truncate(ray_1) == 1);

    // 100 * RAY_SCALE truncates to 100
    let ray_100 = to_ray(100u128);
    assert(truncate(ray_100) == 100);
}

#[test]
fn test_ray_add() {
    // Basic addition: 100 + 50 = 150
    let a = to_ray(100u128);
    let b = to_ray(50u128);
    let result = ray_add(a, b);
    assert(result == to_ray(150u128));

    // Zero properties: a + 0 = a
    let zero = from_u128(0u128);
    assert(ray_add(a, zero) == a);

    // Commutativity: a + b = b + a
    let x = to_ray(123u128);
    let y = to_ray(456u128);
    assert(ray_add(x, y) == ray_add(y, x));
}

#[test]
fn test_ray_sub() {
    // Basic subtraction: 100 - 30 = 70
    let a = to_ray(100u128);
    let b = to_ray(30u128);
    let result = ray_sub(a, b);
    assert(result == to_ray(70u128));

    // Zero properties: a - 0 = a
    let zero = from_u128(0u128);
    assert(ray_sub(a, zero) == a);
}

#[test(should_fail_with = "RAY subtraction underflow")]
fn test_ray_sub_underflow() {
    let _ = ray_sub(to_ray(5u128), to_ray(6u128));
}

#[test]
fn test_ray_mul() {
    // Basic multiplication: 2 * 3 = 6
    let a = to_ray(2u128);
    let b = to_ray(3u128);
    let result = ray_mul(a, b);
    assert(result == to_ray(6u128));

    // Zero multiplication: 0 * x = 0
    let zero = from_u128(0u128);
    assert(ray_mul(zero, to_ray(123u128)) == 0);

    // Identity: 1 * x = x
    let one = to_ray(1u128);
    assert(ray_mul(one, to_ray(42u128)) == to_ray(42u128));

    // Commutativity: a * b = b * a
    let a_val = to_ray(7u128);
    let b_val = to_ray(11u128);
    assert(ray_mul(a_val, b_val) == ray_mul(b_val, a_val));
}

#[test]
fn test_ray_div() {
    // Basic division: 100 / 2 = 50
    let a = to_ray(100u128);
    let b = to_ray(2u128);
    assert(ray_div(a, b) == to_ray(50u128));

    // Identity: x / 1 = x
    let one = to_ray(1u128);
    assert(ray_div(to_ray(42u128), one) == to_ray(42u128));

    // Division by itself: x / x = 1
    let x = to_ray(7u128);
    assert(ray_div(x, x) == one);

    // Zero numerator: 0 / x = 0
    let zero = from_u128(0u128);
    assert(ray_div(zero, to_ray(5u128)) == 0);

    // Fractional: 7 / 2 = 3.5 RAY
    let seven = to_ray(7u128);
    let two = to_ray(2u128);
    let seven_halves = ray_div(seven, two);
    assert(seven_halves == to_ray(3u128) + RAY_SCALE / 2);
}

#[test(should_fail_with = "Division by zero")]
fn test_ray_div_divide_by_zero() {
    let _ = ray_div(from_u128(12u128), 0);
}

#[test]
fn test_ray_mul_div() {
    // Basic: floor(a * b / d) - 100 * 3 / 2 = 150
    let a = to_ray(100u128);
    let b = to_ray(3u128);
    let c = to_ray(2u128);
    assert(ray_mul_div(a, b, c) == to_ray(150u128));

    // Zero multiplication: 0 * a / d = 0
    let zero = from_u128(0u128);
    assert(ray_mul_div(zero, to_ray(100u128), to_ray(5u128)) == 0);

    // Identity: a * 1 / 1 = a
    let one = to_ray(1u128);
    assert(ray_mul_div(to_ray(42u128), one, one) == to_ray(42u128));
}

#[test]
fn test_ray_mul_up() {
    // Basic multiplication with rounding up: 2 * 3 = 6 (exact)
    let a = to_ray(2u128);
    let b = to_ray(3u128);
    assert(ray_mul_up(a, b) == to_ray(6u128));

    // Fractional rounds up: 3 * 0.5 = 1.5 -> rounds up to 2
    let three = to_ray(3u128);
    let half = RAY_SCALE / 2; // 0.5 in RAY
    let three_half_up = ray_mul_up(three, half);
    assert(three_half_up == to_ray(2u128));
}

#[test]
fn test_ray_div_up() {
    // Basic division with rounding up: 100 / 2 = 50 (exact)
    let a = to_ray(100u128);
    let b = to_ray(2u128);
    assert(ray_div_up(a, b) == to_ray(50u128));

    // 81 / 9 = 9 (exact)
    assert(ray_div_up(to_ray(81u128), to_ray(9u128)) == to_ray(9u128));

    // Fractional rounds up: 7 / 2 = 3.5 -> rounds up to 4
    let seven = to_ray(7u128);
    let two = to_ray(2u128);
    let seven_halves_up = ray_div_up(seven, two);
    assert(seven_halves_up == to_ray(4u128));

    // 10 / 3 ~= 3.333 -> rounds up to 4
    assert(ray_div_up(to_ray(10u128), to_ray(3u128)) == to_ray(4u128));

    // Identity: x / 1 = x (exact)
    let one = to_ray(1u128);
    assert(ray_div_up(to_ray(42u128), one) == to_ray(42u128));

    // Zero numerator: 0 / x = 0
    let zero = from_u128(0u128);
    assert(ray_div_up(zero, to_ray(5u128)) == 0);
}

#[test(should_fail_with = "Division by zero")]
fn test_ray_div_up_divide_by_zero() {
    let _ = ray_div_up(from_u128(12u128), 0);
}

#[test]
fn test_ray_mul_div_up() {
    // Basic: ceil(a * b / d) - 100 * 3 / 2 = 150 (exact)
    let a = to_ray(100u128);
    let b = to_ray(3u128);
    let c = to_ray(2u128);
    assert(ray_mul_div_up(a, b, c) == to_ray(150u128));

    // Fractional rounds up: 10 * 3 / 4 = 7.5 -> rounds up to 8
    assert(ray_mul_div_up(to_ray(10u128), to_ray(3u128), to_ray(4u128)) == to_ray(8u128));

    // 7 * 3 / 5 = 4.2 -> rounds up to 5
    assert(ray_mul_div_up(to_ray(7u128), to_ray(3u128), to_ray(5u128)) == to_ray(5u128));

    // 10 * 7 / 9 ~= 7.777 -> rounds up to 8
    assert(ray_mul_div_up(to_ray(10u128), to_ray(7u128), to_ray(9u128)) == to_ray(8u128));

    // 1 * 1 / 3 ~= 0.333 -> rounds up to 1
    assert(ray_mul_div_up(to_ray(1u128), to_ray(1u128), to_ray(3u128)) == RAY_SCALE);

    // Identity: a * 1 / 1 = a (exact)
    let one = to_ray(1u128);
    assert(ray_mul_div_up(to_ray(42u128), one, one) == to_ray(42u128));

    // Zero multiplication: 0 * a / d = 0
    let zero = from_u128(0u128);
    assert(ray_mul_div_up(zero, to_ray(100u128), to_ray(5u128)) == 0);

    // ceil >= floor for all inputs
    let x = to_ray(10u128);
    let y = to_ray(7u128);
    let z = to_ray(9u128);
    let floor_result = ray_mul_div(x, y, z);
    let ceil_result = ray_mul_div_up(x, y, z);
    assert(ceil_result as u128 >= floor_result as u128);

    // Exact division should give same result
    assert(ray_mul_div_up(to_ray(12u128), to_ray(2u128), to_ray(3u128)) == ray_mul_div(to_ray(12u128), to_ray(2u128), to_ray(3u128)));
}

#[test]
fn test_ray_mul_up_zero_multiplicand() {
    // 0 * x should give 0
    let result = ray_mul_up(from_u128(0), to_ray(10u128));
    assert(result == 0);

    // x * 0 should also give 0
    let result2 = ray_mul_up(to_ray(10u128), from_u128(0));
    assert(result2 == 0);
}

#[test(should_fail_with = "Division by zero")]
fn test_ray_mul_div_up_divide_by_zero() {
    let _ = ray_mul_div_up(to_ray(1u128), to_ray(1u128), 0);
}

#[test]
fn test_roundtrip_conversions() {
    // Roundtrip: u128 -> RAY -> u128
    let original = 12345u128;
    let ray = to_ray(original);
    let recovered = truncate(ray);
    assert(recovered == original);
}

#[test]
fn test_arithmetic_properties() {
    let a = to_ray(100u128);
    let zero = from_u128(0u128);
    let one = to_ray(1u128);

    // Addition/subtraction inverse: (a + b) - b = a
    assert(ray_sub(ray_add(a, zero), zero) == a);

    // Zero properties
    assert(ray_mul(a, zero) == 0);
    assert(ray_add(a, zero) == a);
    assert(ray_sub(a, zero) == a);

    // Identity properties
    assert(ray_mul(a, one) == a);
    assert(ray_div(a, one) == a);
}
