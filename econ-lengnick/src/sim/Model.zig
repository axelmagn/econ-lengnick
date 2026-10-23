const std = @import("std");
const Firm = @import("Firm.zig");
const Household = @import("Household.zig");
const SupplierLink = @import("SupplierLink.zig");

const Model = @This();


config: Config,

households: Household.Table,
firms: Firm.Table,
supplier_links: SupplierLink.Table,

rng: std.Random.DefaultPrng,
/// Runs continuously across months (month 1 = days 1-21, month 2 = 22-42).
day: u32,
month: u32,

pub const Config = struct {
    /// H
    num_households: u32 = 1000,
    /// F
    num_firms: u32 = 100,
    /// Working days per month.
    num_days: u32 = 21,
    /// Discarded warm-up period.
    burn_in_months: u32 = 1000,
    /// Recorded simulation length (500 years).
    run_months: u32 = 6000,
    /// RNG seed. The paper gives none; replayable runs are needed for the
    /// impulse-response experiments (p.114).
    seed: u64 = 0,

    household: Household.Config = .{},
    firm: Firm.Config = .{},
    init: Init = .{},

    // Interest rate on savings is 0 (normalized, p.108).
    // Total money stock M is not specified; it follows from `init`.

    /// Initial values. Not defined in the paper (p.109 says only "initial
    /// values"); these are the newwayland/baseline-economy choices (§4).
    pub const Init = struct {
        household_liquidity: u32 = 3100,
        household_reservation_wage: u32 = 0,
        firm_liquidity: u32 = 0,
        firm_price: u32 = 25,
        /// Daily rate; the monthly wage is this times `num_days`.
        firm_daily_wage: u32 = 68,
        firm_inventory: u32 = 0,
        /// Must be > 0, or the inventory bounds are 0 and the firm never hires.
        firm_demand: u32 = 1,
    };
};
