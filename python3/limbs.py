import math
import random

a = 44604940582656816551270015030630754342
b = 26697901239309924063484575321349938637
d = 155890697699702184675385932277532475881

SCALE = 2**64

def get_high_low(num):
    return (num // SCALE, num % SCALE)

(a_h, a_l) = get_high_low(a)
(b_h, b_l) = get_high_low(b)

assert(a_h * SCALE + a_l == a)
assert(b_h * SCALE + b_l == b)

# (a_h * SCALE + a_l) * (b_h * SCALE + b_l)
# term 1: a_h * b_h * SCALE ^ 2 
# term 2: a_h * b_l * SCALE
# term 3: a_l * b_h * SCALE
# term 4: a_l * b_l
# when separating the product as limbs
# limb 0: l(a_l * b_l)
# limb 1: h(a_l * b_l) + l(a_l * b_h) + l(a_h * b_l)
# limb 2: h(a_l * b_h) + h(a_h * b_l) + l(a_h * b_h)
# limb 3: h(a_h * b_h)

pp_ll = a_l * b_l
pp_lh = a_l * b_h
pp_hl = a_h * b_l
pp_hh = a_h * b_h

(pp_ll_h, pp_ll_l) = get_high_low(pp_ll)
(pp_lh_h, pp_lh_l) = get_high_low(pp_lh)
(pp_hl_h, pp_hl_l) = get_high_low(pp_hl)
(pp_hh_h, pp_hh_l) = get_high_low(pp_hh)

limbs = []
limbs.append(pp_ll_l)

limb_sum_1 = pp_lh_l + pp_hl_l + pp_ll_h
carry_1 = limb_sum_1 // SCALE
limbs.append(limb_sum_1 % SCALE)

limb_sum_2 = pp_lh_h + pp_hl_h + pp_hh_l + carry_1 
carry_2 = limb_sum_2 // SCALE
limbs.append(limb_sum_2 % SCALE)

limbs.append(pp_hh_h + carry_2)

assert(
    limbs[3] * SCALE**3 +
    limbs[2] * SCALE**2 +
    limbs[1] * SCALE +
    limbs[0] == 
    a * b
)


r = 0
q_limbs = []
for i in range(0, 4):
    limb_idx = 3 - i
    q_limb = 0
    for j in range(0, 64):
        divisor_idx = 63 - j

        r = (r * 2) + ((limbs[limb_idx] // (2 ** divisor_idx)) % 2)

        if r >= d:
            r = r - d
            q_limb += 2**divisor_idx

    q_limbs.append(q_limb)

qoutient = q_limbs[0] * SCALE**3 + q_limbs[1] * SCALE**2 + q_limbs[2] * SCALE + q_limbs[3]
assert(
    a * b == 
    qoutient * d + r
)

