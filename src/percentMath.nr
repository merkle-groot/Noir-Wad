pub global U128_MAX: u128 = 0xffffffffffffffffffffffffffffffff;
pub global PERCENTAGE_SCALE: u128 = 10_000;
pub global HALF_PERCENTAGE_SCALE: u128 = 5_000;

pub fn multiply_percentage(value: u128, percentage: u128) -> u128 {
    assert(percentage != 0);
    
    assert(value <= (U128_MAX - HALF_PERCENTAGE_SCALE) / percentage);
    (value * percentage + HALF_PERCENTAGE_SCALE) / PERCENTAGE_SCALE
}

pub fn divide_percentage(value: u128, percentage: u128) -> u128 {
    assert(percentage != 0);

    assert(value <= (U128_MAX - percentage / 2) / PERCENTAGE_SCALE);
   (value * PERCENTAGE_SCALE + (percentage / 2)) / percentage
}
    

