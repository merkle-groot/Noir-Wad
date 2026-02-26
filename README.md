# wad.nr

A WAD (Wei-As-Decimal) fixed-point arithmetic library for Noir, targeting the Aztec Network. Provides safe 18-decimal fixed-point math with overflow-resistant `mul_div` operations.

---

## Why WAD?

Token amounts in Ethereum-based systems carry 18 decimal places of precision. A balance of `1.5 USDC` is stored as `1_500_000_000_000_000_000` on-chain. This is fine for storage and transfer, but it creates serious problems the moment you try to do arithmetic.

### Problem 1 — Multiplication overflows

If you multiply two token amounts directly, you get a number that is `10^18` times too large. With u128 arithmetic this almost always overflows:

```
// User has 1000 tokens, price is 1000 tokens per unit
1000 * 10^18 * 1000 * 10^18 = 10^42

u128::MAX ≈ 3.4 * 10^38  ——  OVERFLOW
```

And if you move the multiplication to `Field` to avoid overflow, you now have a 36-decimal number. You cannot simply divide by `10^18` in Field arithmetic to bring it back — `Field` division is modular inversion (`a * b^-1 mod p`), not integer floor division. The integer floor you need simply does not exist as a native `Field` operation.

### Problem 2 — Division truncates precision

If you divide two token amounts using plain integer division, you lose all fractional precision immediately:

```
// What fraction of 3 tokens is 1 token?
(1 * 10^18) / (3 * 10^18) = 0   // integer floor division, result truncated to zero
```

The mathematically correct answer is `0.333...`, which in 18-decimal representation should be `333_333_333_333_333_333`. To get there, you need to scale the numerator up by `10^18` before dividing: `(a * 10^18) / b`. But now you are back to the overflow problem — `a * 10^18` may overflow `u128` before the division can rescue it.

### Problem 3 — You need multiplication and division together, atomically

Both problems above collapse into the same root issue: you need to compute `floor(a * b / d)` as a single atomic operation, where the intermediate product `a * b` may exceed any fixed-width integer type, but the final result fits comfortably. You cannot split this into a multiply-then-divide without an intermediate overflow, and you cannot do it in `Field` arithmetic without losing floor semantics.

This comes up everywhere in DeFi:
- `wad_mul(price, amount)` — rescale a product back to token decimals
- `wad_div(a, b)` — compute a ratio without truncating to zero
- Swap output amounts, fee calculations, interest accrual, price impact — all of these are `floor(a * b / d)` under the hood

### The WAD solution

WAD fixes this by:

1. **Representing all values pre-scaled** — `1.5` is stored as `1_500_000_000_000_000_000`. Addition and subtraction work directly with no changes.

2. **Providing `wad_mul_div(a, b, d)`** — computes `floor(a * b / d)` using a 256-bit intermediate representation in unconstrained code, then verifies the result in the ZK circuit with the constraint `a * b == q * d + r`. No overflow, no precision loss, fully ZK-verifiable.

3. **Deriving `wad_mul` and `wad_div` from `wad_mul_div`**:
   - `wad_mul(a, b)` = `wad_mul_div(a, b, SCALE)` — multiplies and rescales in one step
   - `wad_div(a, b)` = `wad_mul_div(a, SCALE, b)` — scales up before dividing, preserving all decimals

```
// Correct WAD multiplication
wad_mul(1000 * 10^18, 1000 * 10^18)
= floor(1000 * 10^18 * 1000 * 10^18 / 10^18)
= 1_000_000 * 10^18   ✓   (no overflow, correct decimals)

// Correct WAD division  
wad_div(1 * 10^18, 3 * 10^18)
= floor(1 * 10^18 * 10^18 / 3 * 10^18)
= floor(10^18 / 3)
= 333_333_333_333_333_333   ✓   (0.333... WAD, no truncation to zero)
```

---
## Installation

Add the library to your `Nargo.toml`:

```toml
[dependencies]
wad = { git = "https://github.com/merkle-groot/Noir-Wad", tag = "main"}
```

Then import in your Noir source:

```noir
use wad::{to_wad, wad_mul, wad_div, wad_mul_div, truncate, wad_add, wad_sub, from_u128};
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

#### `to_wad(value: u128) -> Wad`
Converts a plain integer to WAD format by multiplying by `SCALE`.

```noir
let w = to_wad(5u128); // w == 5 * 10^18
```

#### `from_u128(value: u128) -> Wad`
Raw cast — no scaling. Use when the value is already in WAD units or is a raw sub-unit amount.

```noir
let w = from_u128(500_000_000_000_000_000u128); // w == 0.5 WAD
```

#### `truncate(value: Wad) -> u128`
Extracts the integer part of a WAD value, discarding the fractional portion (floor).

```noir
let w = to_wad(7u128) + SCALE / 2; // 7.5 WAD
truncate(w); // == 7
```

---

### Arithmetic

#### `wad_add(a: Wad, b: Wad) -> Wad`
Adds two WAD values.

```noir
wad_add(to_wad(3u128), to_wad(4u128)); // == to_wad(7)
```

#### `wad_sub(a: Wad, b: Wad) -> Wad`
Subtracts `b` from `a`. Panics on underflow.

```noir
wad_sub(to_wad(10u128), to_wad(3u128)); // == to_wad(7)
```

#### `wad_mul(a: Wad, b: Wad) -> Wad`
Multiplies two WAD values and rescales: `floor(a * b / SCALE)`.

```noir
wad_mul(to_wad(3u128), to_wad(4u128)); // == to_wad(12)
wad_mul(to_wad(3u128), SCALE / 2);     // == to_wad(1) + SCALE/2  (1.5 WAD)
```

#### `wad_div(a: Wad, b: Wad) -> Wad`
Divides two WAD values: `floor(a * SCALE / b)`. Preserves fractional precision.

```noir
wad_div(to_wad(7u128), to_wad(2u128)); // == to_wad(3) + SCALE/2  (3.5 WAD)
```

#### `wad_mul_div(a: Field, b: Field, d: Field) -> Field`
The core primitive. Computes `floor(a * b / d)` without intermediate overflow, using a 256-bit long-division algorithm in an unconstrained hint verified by a circuit constraint.

```noir
// Apply a ratio: amount * numerator / denominator, in one atomic step
wad_mul_div(to_wad(1000u128), to_wad(3u128), to_wad(7u128)); // == to_wad(428) + ...
```

All higher-level functions delegate to this:
- `wad_mul(a, b)` = `wad_mul_div(a, b, SCALE)`
- `wad_div(a, b)` = `wad_mul_div(a, SCALE, b)`

---

## Safety & Constraints

### Input range

All inputs to `wad_mul_div` must satisfy `value < 2^127`. This is enforced by constrained range checks inside the function — proof generation fails if any input violates this bound.

The limit exists because `wad_mul_div` verifies its result in BN254 `Field` arithmetic using the constraint `a * b == q * d + r`. The BN254 field modulus is `p ≈ 2^254`. If `a * b >= p`, the product wraps mod `p` and the constraint can be satisfied by a forged quotient. By bounding all inputs to `< 2^127`, we guarantee `a * b < 2^254 < p`, making the constraint sound — `Field` equality implies integer equality.

### Safe input ceilings

| Constant | Value | Meaning |
|---|---|---|
| `MAX_WAD_CONVERTIBLE` | `340_282_366_920_938_463_463` | Largest `x` where `to_wad(x)` fits in `u128` |
| `MAX_WAD_MUL_DIV_INT` | `170_141_183_460_469_231_731` | Largest `x` where `to_wad(x)` passes the `< 2^127` range check in `wad_mul_div` |
| `MAX_WAD_MUL_INT` | `13_043_817_825` | Largest `x` where `wad_mul(to_wad(x), to_wad(x))` result is still `< 2^127` |

`MAX_WAD_MUL_DIV_INT ≈ 1.7 × 10^20` means any token amount below ~170 quintillion units is safe as input to `wad_mul_div`. This covers all realistic DeFi amounts.

### Nested floor identity

`floor(floor(N / a) / b) == floor(N / (a * b))` holds unconditionally — no exact division required. Chained `wad_mul_div` calls can always be collapsed into a single call with a combined denominator, with identical results and no accumulated rounding error.

### `wad_mul` is not associative

Due to flooring at each step, `wad_mul(wad_mul(a, b), c)` can differ from `wad_mul(a, wad_mul(b, c))` when values do not divide exactly. When precision matters, prefer a single `wad_mul_div` call with the combined denominator over chained `wad_mul` calls.

### How `wad_mul_div` works

1. **Constrained range checks** — `a`, `b`, `d` are cast to `u128` in constrained context (panics if `>= 2^128`) then asserted `< 2^127`.
2. **Unconstrained hint** — a 256-bit long division computes `(quotient, remainder)` using four 64-bit limbs in `u128` arithmetic, with no modular reduction.
3. **Circuit verification** — the constrained context checks `a * b == quotient * d + remainder` in `Field`, and `remainder < d`. Because inputs are `< 2^127`, `a * b < p` and `Field` equality implies integer equality.
4. **Quotient range check** — `quotient` is range-checked to prevent a malicious prover from supplying `quotient + k*p` as a forged witness.

---

## Examples

### Token swap output

```noir
// Uniswap-style: output = reserve_out * amount_in / (reserve_in + amount_in)
let reserve_in  = to_wad(100_000u128);
let reserve_out = to_wad(200_000u128);
let amount_in   = to_wad(1_000u128);
let amount_out  = wad_mul_div(reserve_out, amount_in, wad_add(reserve_in, amount_in));
truncate(amount_out); // == 1980  (with slippage)
```

### Fee calculation

```noir
// 0.3% fee on 10,000 tokens
let amount   = to_wad(10_000u128);
let fee_rate = SCALE * 3 / 1000; // 0.003 WAD
let fee      = wad_mul(amount, fee_rate);
truncate(fee); // == 30
```

### Interest accrual

```noir
// Apply a 5% APR over a fraction of a year
// interest = principal * rate * time_fraction
let principal     = to_wad(1_000u128);
let annual_rate   = SCALE * 5 / 100;   // 0.05 WAD
let time_fraction = SCALE / 12;         // 1/12 of a year (1 month)
let interest      = wad_mul(wad_mul(principal, annual_rate), time_fraction);
truncate(interest); // == 4  (floor of 4.166...)
```

### Price from reserves

```noir
// price = reserve_b / reserve_a  (preserves all decimal precision)
let reserve_a = to_wad(100_000u128);
let reserve_b = to_wad(350_000u128);
let price     = wad_div(reserve_b, reserve_a); // 3.5 WAD
truncate(price); // == 3
```

---

## Comparison: wad_mul_div vs noir-bignum

An alternative implementation using [noir-bignum](https://github.com/noir-lang/noir-bignum)'s `U256` type was evaluated. noir-bignum is a general-purpose arbitrary-precision library designed for operations like RSA, ECC, and cross-curve arithmetic where inputs can reach thousands of bits. This comparison exists to document why that approach was not used.

### Opcode counts

Measured with `nargo compile --print-acir` on identical `wad_mul_div(a, b, d)` inputs:

| Function | wad.nr | noir-bignum |
|---|---|---|
| `main` | **81** | 163 |
| multiply (unconstrained) | **271** | 925 |
| divide (unconstrained) | — | 1616 |
| quadratic constraint | — | 1823 |
| range / borrow checks | — | 98 + 191 |
| **Total** | **~360** | **~4816** |

**wad.nr is ~13x fewer opcodes** for the same operation.

### Why the difference

noir-bignum represents every number as three 120-bit limbs to support up to 257-bit moduli. Every multiplication and comparison runs Barrett reduction across all three limbs, even when the values easily fit in a single limb.

wad.nr exploits the fact that WAD inputs are always `< 2^127`:

```
noir-bignum verification:
  __mul(a_bn, b_bn)              → 3-limb product   (925 opcodes)
  __udiv_mod(product, d_bn)      → 3-limb quotient  (1616 opcodes)
  evaluate_quadratic_expression  → Barrett reduction (1823 opcodes)

wad.nr verification:
  unconstrained_mul_div(a, b, d) → (quotient, remainder)  (271 opcodes)
  assert(a * b == q * d + r)     → 1 native Field gate    (part of main: 81)
```

The single Field constraint `a * b == q * d + r` is sound because inputs are bounded to `< 2^127`, so `a * b < 2^254 < p` (BN254 field modulus). Field equality implies integer equality — no multi-limb arithmetic needed.

### Compiler safety

Noir's Brillig safety checker also rejects the bignum approach for this pattern. Because `__mul` and `__udiv_mod` are chained unconstrained calls, the intermediate `product` value is never directly referenced in a circuit constraint:

```
// Brillig checker error:
// "This Brillig call's inputs and its return values haven't been
//  sufficiently constrained"
let product = unsafe { a_bn.__mul(b_bn) };
let (q, r)  = unsafe { product.__udiv_mod(d_bn) };
```

wad.nr's single unconstrained call returns `(quotient, remainder)` which are immediately and visibly consumed by the Field constraint — the checker passes with no warnings.

### When to use each

| | wad.nr | noir-bignum |
|---|---|---|
| Input size | `< 2^127` | up to `2^8192` |
| Use case | DeFi token arithmetic | RSA, ECC, cross-curve |
| Verification cost | 1 Field gate | Barrett reduction |
| Brillig safety | ✓ passes | ✗ fails for muldiv pattern |
| Soundness | proven for `< 2^127` | proven for arbitrary size |

For WAD arithmetic where inputs are always 18-decimal token amounts, wad.nr's hand-rolled approach is the correct choice. noir-bignum is the correct choice when inputs genuinely exceed `2^127`.

---

## Running Tests

```bash
nargo test
```

Tests in `src/wad.nr` cover:

- Basic arithmetic and identity properties
- Commutativity, distributivity
- Fractional floor behaviour and repeating decimals
- Roundtrip conversions `u128 → WAD → u128`
- Zero and boundary inputs
- Overflow rejection for `u128` ceiling and `2^127` range bound
- Field modulus boundary soundness
- Nested floor identity with exact and non-exact divisors
- Non-associativity of `wad_mul` counterexample

---

## Limitations

- **Unsigned only** — no negative numbers. `wad_sub` panics on underflow.
- **Floor division only** — no rounding modes. `truncate(wad_div(7, 2)) == 3`, not `4`.
- **`wad_mul` is not associative** — use a single `wad_mul_div` call where exact composition matters.
- **Max safe input `< 2^127`** — see constants above for the precise integer ceilings per operation.
- **`wad_add` does not guard against overflow** — caller is responsible for ensuring the sum does not exceed `u128::MAX` if the result will be passed to `truncate` or further arithmetic.

---

## License

MIT
