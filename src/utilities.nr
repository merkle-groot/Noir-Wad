pub use ray::{
    Ray,
    to_ray,
    ray_mul,
    ray_mul_up,
    ray_add,
    ray_sub,
    ray_div,
    ray_div_up,
    ray_mul_div,
    ray_mul_div_up,
    MAX_RAY_CONVERTIBLE,
    MAX_RAY_MUL_DIV_INT,
    MAX_RAY_MUL_INT,
    RAY_SCALE
};

pub global SECONDS_PER_YEAR = 31_536_000;

pub fn get_simple_interest_multiplier(rate: Ray, seconds_elapsed: u128) -> Ray {
    let result = rate * seconds_elapsed;
    RAY_SCALE + result / SECONDS_PER_YEAR;
}

pub fn get_compound_interest_multiplier(rate: Ray, seconds_elapsed: u128) -> Ray {
    if seconds_elapsed == 0 {
        return RAY_SCALE;
    }

    let exp = seconds_elapsed;
    let exp_minus_one = seconds_elapsed - 1;
    let exp_minus_two = 0;

    if seconds_elapsed != 1 {
        exp_minus_two = seconds_elapsed - 2;
    }

    let base_power_one = rate / SECONDS_PER_YEAR;
    let base_power_two = ray_mul_up(base_power_one, rate) / (SECONDS_PER_YEAR);
    let base_power_three = ray_mul_up(base_power_two, rate) / (SECONDS_PER_YEAR);

    let first_term = (exp * base_power_one);
    let second_term = (exp * exp_minus_one * base_power_two) / 2;
    let third_term = (exp * exp_minus_one * exp_minus_two * base_power_three) / 6;

    return RAY_SCALE + first_term + second_term + third_term;
}