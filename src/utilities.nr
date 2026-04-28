pub use crate::ray::{
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
    ray_int_div,
    ray_int_mul,
    MAX_RAY_CONVERTIBLE,
    MAX_RAY_MUL_DIV_INT,
    MAX_RAY_MUL_INT,
    RAY_SCALE
};

pub global SECONDS_PER_YEAR: u128 = 31_536_000;

pub fn get_simple_interest_multiplier(rate: Ray, seconds_elapsed: u128) -> Ray {
    let result = ray_int_mul(rate, seconds_elapsed);
    RAY_SCALE + ray_int_div(result, SECONDS_PER_YEAR)
}

pub fn get_compound_interest_multiplier(rate: Ray, seconds_elapsed: u128) -> Ray {
    let mut result = RAY_SCALE;
    if seconds_elapsed != 0 {
        let exp = seconds_elapsed;
        let exp_minus_one = seconds_elapsed - 1;
        let mut exp_minus_two = 0;

        if seconds_elapsed != 1 {
            exp_minus_two = seconds_elapsed - 2;
        }

        let base_power_one = ray_int_div(rate, SECONDS_PER_YEAR);
        let base_power_two = ray_int_div(ray_mul_up(base_power_one, rate), SECONDS_PER_YEAR);
        let base_power_three = ray_int_div(ray_mul_up(base_power_two, rate), SECONDS_PER_YEAR);

        let first_term = ray_int_mul(base_power_one, exp);
        let second_term = ray_int_div(ray_int_mul(base_power_two, exp * exp_minus_one), 2);
        let third_term = ray_int_div(ray_int_mul(base_power_three, exp * exp_minus_one * exp_minus_two), 6);

        result = RAY_SCALE + first_term + second_term + third_term;
    }
    
    result
}