# wad.nr

A WAD (Wei-As-Decimal) fixed-point arithmetic library for Noir, targeting the Aztec Network. Provides safe 18-decimal fixed-point math with overflow-resistant `mul_div` operations suitable for use in zero-knowledge circuits.

---

## What is WAD?

WAD is a fixed-point number format borrowed from Ethereum's token standards. All values are scaled by `10^18` (one "WAD unit"), so the integer `1` is represented internally as `1_000_000_000_000_000_000`. This lets you do fractional arithmetic using only integer operations — no floating point required.

```
1.5  →  1_500_000_000_000_000_000  (1.5 × 10^18)
0.5  →    500_000_000_000_000_000  (0.5 × 10^18)
100  →  100_000_000_000_000_000_000 (100 × 10^18)
```

All values are stored as Noir `Field` elements.

---

## Installation

Add the library to your `Nargo.toml`:

```toml
[dependencies]
wad = { path = "../wad_lib" }
```

Then import in your Noir source:

```noir
use wad::{toWad, wad_mul, wad_div, wad_mul_div, truncate, add, sub, fromU128};
```

---

## API Reference

### Type

```noir
pub type Wad = Field;
global SCALE: Field = 1_000_000_000_000_000_000; // 10^18
```

---

### Conversions

#### `toWad(value: u128) -> Wad`
Converts a plain integer to WAD format by multiplying by `SCALE`.

```noir
let w = toWad(5u128); // w == 5 * 10^18
```

#### `fromU128(value: u128) -> Wad`
Raw cast — no scaling. Use when the value is already in WAD units.

```noir
let w = fromU128(500_000_000_000_000_000u128); // w == 0.5 WAD
```

#### `truncate(value: Wad) -> u128`
Extracts the integer part of a WAD value, discarding the fractional portion (floor).

```noir
let w = toWad(7u128) + SCALE / 2; // 7.5 WAD
truncate(w); // == 7
```

---

### Arithmetic

#### `add(a: Wad, b: Wad) -> Wad`
Adds two WAD values.

```noir
add(toWad(3u128), toWad(4u128)); // == toWad(7)
```

#### `sub(a: Wad, b: Wad) -> Wad`
Subtracts `b` from `a`. Panics on underflow.

```noir
sub(toWad(10u128), toWad(3u128)); // == toWad(7)
```

#### `wad_mul(a: Wad, b: Wad) -> Wad`
Multiplies two WAD values and rescales: `floor(a * b / SCALE)`.

```noir
wad_mul(toWad(3u128), toWad(4u128)); // == toWad(12)
wad_mul(toWad(3u128), SCALE / 2);   // == toWad(1) + SCALE/2  (1.5 WAD)
```

#### `wad_div(a: Wad, b: Wad) -> Wad`
Divides two WAD values and rescales: `floor(a * SCALE / b)`.

```noir
wad_div(toWad(7u128), toWad(2u128)); // == toWad(3) + SCALE/2  (3.5 WAD)
```

#### `wad_mul_div(a: Field, b: Field, d: Field) -> Field`
The core primitive. Computes `floor(a * b / d)` without intermediate overflow, using a 256-bit long-division algorithm in an unconstrained hint and verifying the result with a circuit constraint.

```noir
// Equivalent to wad_mul:
wad_mul_div(a, b, SCALE);

// Equivalent to wad_div:
wad_mul_div(a, SCALE, d);

// Combined operation — e.g. apply a ratio:
// result = amount * numerator / denominator
wad_mul_div(toWad(1000u128), toWad(3u128), toWad(4u128)); // 750 WAD
```

---

## Safety & Constraints

### Input range

All inputs to `wad_mul_div` must fit within `u128` (i.e. `< 2^128`). This is enforced by constrained range checks inside the function — proof generation will fail if any input exceeds this bound.

Additionally, to guarantee that `a * b` does not wrap around the BN254 field modulus (`p ≈ 2^254`), inputs must be **strictly less than `2^127`**. Values at or above `2^127` will be rejected:

```
Safe input range:  0  ≤  value  <  2^127
                   (0 to 0x7fffffffffffffffffffffffffffffff)
```

In practice this is not a limitation for WAD-formatted values. `toWad(x)` produces `x * 10^18`, and the safe ceiling for `x` is:

```
2^127 / 10^18  ≈  170_141_183_460_469
```

So any token amount below ~170 trillion units is safe, which covers all realistic DeFi use cases.

### How `wad_mul_div` works

1. **Unconstrained hint** — a 256-bit long division computes `(quotient, remainder)` using four 64-bit limbs, operating entirely in `u128` arithmetic to avoid Field modular reduction.
2. **Circuit constraint** — the constrained context verifies `a * b == quotient * d + remainder` in `Field`.
3. **Range checks** — both `remainder < d` and `quotient` are range-checked to ensure uniqueness of the solution.

The unconstrained computation is a **hint only** — a malicious prover who supplies wrong values will fail the circuit constraint.

---

## Examples

### Token ratio calculation

```noir
// How much of token B do I get for 500 token A, at a rate of 1.25 B per A?
let amount_a   = toWad(500u128);
let rate       = toWad(1u128) + SCALE / 4; // 1.25 WAD
let amount_b   = wad_mul(amount_a, rate);
truncate(amount_b); // == 625
```

### Fee calculation

```noir
// Apply a 0.3% fee
let amount       = toWad(10000u128);
let fee_rate     = SCALE * 3 / 1000; // 0.003 WAD
let fee          = wad_mul(amount, fee_rate);
truncate(fee); // == 30
```

### Price-weighted average

```noir
// floor(price * quantity / total_supply)
let price        = toWad(42u128);
let quantity     = toWad(7u128);
let total_supply = toWad(12u128);
let result       = wad_mul_div(price, quantity, total_supply);
truncate(result); // == 24
```

---

## Running Tests

```bash
nargo test
```

All tests are in `src/wad.nr` under the `#[test]` attribute. Edge cases covered include:

- Basic arithmetic and identity properties
- Commutativity, associativity, distributivity
- Fractional floor behaviour
- Zero and boundary inputs
- Overflow rejection (`should_fail` tests)
- Field-modulus boundary soundness

---

## Limitations

- **No negative numbers** — all values are unsigned. `sub` panics on underflow.
- **Floor division only** — no rounding modes.
- **Max safe input ~2^127** — values larger than `0x7fffffffffffffffffffffffffffffff` are rejected by the range check.
- **No overflow detection for `add`** — caller is responsible for ensuring the sum fits in `Field`.

---

## License

MIT