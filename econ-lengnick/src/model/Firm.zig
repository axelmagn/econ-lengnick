const std = @import("std");
const Currency = @import("units.zig").Currency;
const Goods = @import("units.zig").Goods;
const Household = @import("Household.zig");


const Firm = @This();


liquidity: Currency,
inventory: Goods,
price: Currency,
wage: Currency,
demand_requested: Goods,
units_sold: Goods,
open_position: bool,
months_since_hire_failure: u8,
worker_on_notice: ?Household.Id,

// related:
// employees - intrusive list on households


pub const Id = usize;
pub const Table = std.MultiArrayList(@This());


pub const Config = struct {
    num_firms: 100,
    wage_cut_months: u8,
    wage_step_max: f32,
    inventory_upper_ratio: f32,
    inventory_lower_ratio: f32,
    price_upper_markup: f32,
    price_lower_markup: f32,
    price_step_max: f32,
    price_change_prob: f32,
    productivity: u8,
    buffer_ratio: f32,
};


