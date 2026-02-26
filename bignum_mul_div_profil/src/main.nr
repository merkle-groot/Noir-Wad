use ::bignum::{U256, BigNum};
use ::bignum::bignum::evaluate_quadratic_expression;

/// Performs mul_div using noir-bignum's U256 type
///
/// This uses noir-bignum's unconstrained multiplication (__mul) and integer
/// division (udiv_mod) to compute floor(a * b / d) for arbitrary precision numbers.
pub fn bignum_mul_div(a: Field, b: Field, d: Field) -> Field {
    assert(d != 0, "Division by zero");

    let a_int = a as u128;
    let b_int = b as u128;
    let d_int = d as u128;
    let U127: u128 = 0x80000000000000000000000000000000;
    assert(a_int < U127, "a out of safe range");
    assert(b_int < U127, "b out of safe range");
    assert(d_int < U127, "d out of safe range");

    let a_bn = U256::from(a);
    let b_bn = U256::from(b);
    let d_bn = U256::from(d);

    // Chain mul into udiv_mod so `product` is never a named unconstrained variable
    let (quotient_bn, remainder_bn) = unsafe {
        a_bn.__mul(b_bn).__udiv_mod(d_bn)
    };

    // Constrain: a*b - quotient*d - remainder = 0
    // This is the actual circuit constraint tying quotient and remainder
    // back to the original inputs a_bn and b_bn
    evaluate_quadratic_expression(
        [[a_bn],  [quotient_bn]],
        [[false], [true]],       // quotient negated
        [[b_bn],  [d_bn]],
        [[false], [false]],
        [remainder_bn],
        [true],                  // remainder negated
    );

    // Constrain remainder < d (uniqueness of quotient/remainder pair)
    assert(remainder_bn < d_bn, "Invalid remainder");

    // Reconstruct Field from limbs safe since quotient < 2^127 < 2^240
    let limbs = quotient_bn.get_limbs();
    assert(limbs[2] == 0, "Quotient exceeds safe range");
    let two_pow_120: Field = 0x1000000000000000000000000000;
    (limbs[0] as Field) + (limbs[1] as Field) * two_pow_120
}

pub fn main(a: pub Field, b: pub Field, d: pub Field) -> pub Field {
    bignum_mul_div(a, b, d)
}
