const std = @import("std");
const units = @import("units.zig");
const Household = @import("Household.zig");

const Firm = @This();

const Goods = units.Goods;
const Money = units.Money;

liquidity: Money,
inventory: Goods,
price: Money,
/// One wage rate per firm, paid monthly to every employee.
wage: Money,
/// Units requested from this firm this month, whether or not it had the
/// stock. Last month's value serves as d_f^old in Eqs. 6-7 (current choice).
demand_requested: Goods,
/// Units sold this month. Alternative measure for d_f^old.
units_sold: Goods,
/// At most one vacancy; persists across months until filled or cancelled.
open_position: bool,
/// Months in a row that ended with no unfilled open position.
months_since_hire_failure: u32,
/// Worker given notice; keeps working until fired at the next month start.
worker_on_notice: ?Household.Id,

pub const Id = u32;
pub const Table = std.MultiArrayList(Firm);

/// Shared by all firms, constant. Values are Table 1 (p.110).
/// Requires 0 < inv_lower_ratio < inv_upper_ratio and
/// 1 < price_lower_markup < price_upper_markup.
pub const Config = struct {
    /// γ: months in a row with all positions filled before the wage is cut.
    wage_cut_months: u32 = 24,
    /// δ: upper bound of the wage growth rate, μ ~ U(0, δ).
    wage_step_max: f64 = 0.019,
    /// φ̄: upper inventory bound as a fraction of last month's demand.
    inv_upper_ratio: f64 = 1,
    /// φ̲: lower inventory bound as a fraction of last month's demand.
    inv_lower_ratio: f64 = 0.25,
    /// ϕ̄: upper price bound as a markup on marginal cost.
    price_upper_markup: f64 = 1.15,
    /// ϕ̲: lower price bound as a markup on marginal cost.
    price_lower_markup: f64 = 1.025,
    /// ϑ: upper bound of the price growth rate, ν ~ U(0, ϑ).
    price_step_max: f64 = 0.02,
    /// θ: probability of changing the price when conditions call for it.
    price_change_prob: f64 = 0.75,
    /// λ: goods produced per worker per day.
    productivity: Goods = 3,
    /// χ: liquidity buffer as a fraction of the wage bill.
    buffer_ratio: f64 = 0.1,
};
