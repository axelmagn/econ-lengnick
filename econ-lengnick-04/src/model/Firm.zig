//! Firm agent that hires workers, produces goods, manages inventory, sets
//! prices and wages, and distributes profits.
const std = @import("std");
const Position = @import("units.zig").Position;
const Currency = @import("units.zig").Currency;
const Goods = @import("units.zig").Goods;
const Household = @import("Household.zig");
const traits = @import("../core/traits.zig");

const ncast = @import("../core/num_cast.zig").num_cast;

/// position in the world map
position: Position,
/// Operating cash balance accumulating sales revenue, deducted for monthly
/// wages, and reset to zero during profit redistribution.
liquidity: Currency,
/// Current stock of finished goods available for sale, increased by
/// production and reduced by customer purchases.
inventory: Goods,
/// Selling price per unit of goods, updated with Calvo stickiness within
/// markup bounds over marginal cost.
price: Currency,
/// Monthly wage rate offered to current employees and prospective hires.
wage: Currency,
/// Indicates whether the firm has an open job vacancy posted for the current month.
open_position: bool,
/// Indicates whether the firm had an open position last month that remained unfilled.
// (I think I can reuse open_position instead)
// unfilled_positions_last_month: bool,
/// Number of consecutive months the firm has operated with all positions
/// fully staffed without unfilled vacancies.
consecutive_full_months: u32,
/// Identifier of the employee scheduled to be dismissed at the end of the
/// month following the statutory notice period.
on_notice: Household.Id,
/// Total volume of goods demanded by customers during the previous month,
/// used to set inventory buffer thresholds.
demand_last_month: Goods,
/// Running total of goods demanded by customers during the current month.
demand_current_month: Goods,
/// The first employee in a linked list
employees_first: Household.Id,
/// The number of employees
employees_len: usize,

const Firm = @This();

/// Unique identifier for a firm agent.
const Id = usize;

/// Production, pricing, and labor parameters for firm agents.
const Config = struct {
    /// Daily units of goods produced by each employed worker.
    labor_productivity: u32 = 3,
    /// Upper bound for random proportional wage adjustment shocks.
    wage_shock_bound: f32 = 0.019,
    /// Required number of consecutive fully staffed months before a firm lowers its wage rate.
    full_employment_memory: u32 = 24,
    /// Lower inventory buffer fraction of last month's demand below which
    /// a firm opens a vacancy and considers raising prices.
    inventory_lower_bound: f32 = 0.25,
    /// Upper inventory buffer fraction of last month's demand above which
    /// a firm issues a dismissal notice and considers lowering prices.
    inventory_upper_bound: f32 = 1.0,
    /// Minimum markup multiplier applied to unit marginal labor cost to
    /// define the lower price bound.
    price_markup_min: f32 = 1.025,
    /// Maximum markup multiplier applied to unit marginal labor cost to
    /// define the upper price bound.
    price_markup_max: f32 = 1.15,
    /// Upper bound for random proportional price adjustment shocks.
    price_adjustment_bound: f32 = 0.02,
    /// Calvo probability of attempting a price change when inventory is
    /// outside the target buffer bounds.
    calvo_price_prob: f32 = 0.75,
    /// Initial monthly contractual wage offered by all firms at the start of the simulation.
    initial_wage: Currency = .from(1),
    // initial_workers_per_firm: u32 = 10, // DERIVE: distribute workers for 100% employment
    /// Initial price markup percentage above marginal cost at the start of the simulation.
    initial_price_markup: f32 = 0.10,
    // initial_inventory: Goods = 630, // DERIVE: exactly 1 month of normal production
    // initial_demand_history: Goods = 630 // DERIVE: exactly 1 month of normal production
    // initial_consecutive_full: u32 = 24 // DERIVE: same as employment memory
};

// const Event = union(enum) {
//     fire_random_employee,
// };
//
// const IdEvent = struct {
//     firm: Id,
//     event: Event,
// };

fn RandomEmployee(T: type) type {
    return struct {
        get: fn (T) ?Household.Id,
    };
}

/// firm evaluates its staffing conditions and adjusts its wages
pub fn review_wage(
    wage: *Currency,
    consecutive_full_months: *u32,
    open_position: bool,
    wage_shock_bound: f32,
    full_employment_memory: u32,
    rng: std.Random,
) void {
    // if open position at time of review (beginning of month), labor shortage
    if (open_position) {
        const wage_delta = 1 + rng.float(f32) * wage_shock_bound;
        wage.* = wage.mul(wage_delta);
        consecutive_full_months.* = 0;
        // if full employment for recent memory, labor surplus (lower wages)
    } else if (consecutive_full_months.* >= full_employment_memory) {
        const wage_delta = @max(0, 1 - rng.float(f32) * wage_shock_bound);
        wage.* = wage.mul(wage_delta);
    }
}

test review_wage {
    const bound: f32 = 0.019;
    const memory: u32 = 24;
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    const initial_wage = Currency.from(1000);

    // open position: labor shortage raises the wage within the shock bound
    // and resets the full-employment streak
    {
        var wage = initial_wage;
        var consecutive_full_months: u32 = memory;
        review_wage(&wage, true, &consecutive_full_months, bound, memory, rng);
        try std.testing.expect(wage.scaled_value > initial_wage.scaled_value);
        try std.testing.expect(
            wage.scaled_value <= initial_wage.mul(1 + bound).scaled_value,
        );
        try std.testing.expectEqual(@as(u32, 0), consecutive_full_months);
    }

    // fully staffed for the whole memory: wage is cut within the shock
    // bound, streak keeps counting
    {
        var wage = initial_wage;
        var consecutive_full_months: u32 = memory;
        review_wage(&wage, false, &consecutive_full_months, bound, memory, rng);
        try std.testing.expect(wage.scaled_value < initial_wage.scaled_value);
        try std.testing.expect(
            wage.scaled_value >= initial_wage.mul(1 - bound).scaled_value,
        );
        try std.testing.expectEqual(memory, consecutive_full_months);
    }

    // fully staffed but below the memory threshold: nothing changes
    {
        var wage = initial_wage;
        var consecutive_full_months: u32 = memory - 1;
        review_wage(&wage, false, &consecutive_full_months, bound, memory, rng);
        try std.testing.expectEqual(initial_wage, wage);
        try std.testing.expectEqual(memory - 1, consecutive_full_months);
    }
}

/// firm plans production and labor targets for the month
pub fn plan_production(
    open_position: *bool,
    on_notice: *Household.Id,
    inventory: Goods,
    demand_last_month: Goods,
    inventory_lower_bound: f32,
    inventory_upper_bound: f32,
    random_employee_impl: anytype,
    random_employee_trait: RandomEmployee(@TypeOf(random_employee_impl)),
) void {
    const inventory_lower = ncast(f32, demand_last_month) * inventory_lower_bound;
    const inventory_upper = ncast(f32, demand_last_month) * inventory_upper_bound;
    const inventory_f: f32 = @floatFromInt(inventory);

    if (inventory_f < inventory_lower) {
        // if inventory is low, we need to hire
        on_notice.* = 0; // cancel any employees on notice
        open_position.* = true;
    } else if (inventory_f > inventory_upper) {
        // if inventory is high, we need to fire
        open_position.* = false;
        // put random employee on notice
        if (random_employee_trait.get(random_employee_impl)) |employee| {
            on_notice.* = employee;
        }
    } else {
        // otherwise inventory is in-bounds - don't change staffing
        open_position.* = false;
    }
}

pub fn adjust_prices(
    price: *Currency,
    wage: Currency,
    days_per_month: u32,
    labor_productivity: u32,
) void {
    const marginal_cost = wage.div(days_per_month * labor_productivity);
}
