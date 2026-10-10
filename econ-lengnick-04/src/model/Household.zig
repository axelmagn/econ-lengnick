//! Household agent that supplies labor, earns wages and profit shares, and purchases goods.
const std = @import("std");
const Position = @import("units.zig").Position;
const Currency = @import("units.zig").Currency;
const CurrencyOps = @import("units.zig").CurrencyOps;
const Goods = @import("units.zig").Goods;
const Firm = @import("Firm.zig");

const Household = @This();

/// position in the world map
position: Position,
/// Current cash balance held by the household, subject to cash-in-advance constraints.
liquidity: Currency,
/// Minimum acceptable monthly wage required to accept employment.
/// Increases when higher wages are earned and decreases during
/// unemployment.
reservation_wage: Currency,
/// Identifier of the firm currently employing this household, or an
/// unassigned value if unemployed.
employer_id: Firm.Id,
/// Planned volume of real goods to consume over the current month, based
/// on cash holdings, average prices, and consumption preferences.
monthly_planned_consumption: Goods,
/// reference to next coworker in intrusive linked list
employees_next: Household.Id,

/// Unique identifier for a household agent.
const Id = usize;

/// Behavioral parameters and settings for household agents.
const Config = struct {
    /// Curvature parameter representing the non-linear marginal propensity
    /// to consume out of real money balances.
    consumption_exponent: f32 = 0.9,
    /// Fixed number of supplier firms each household connects to for purchasing goods.
    supplier_network_size: u32 = 7,
    /// Monthly probability that a household searches for a cheaper
    /// supplier to replace an existing one.
    price_search_prob: f32 = 0.25,
    /// Minimum percentage price reduction required to switch from a
    /// current supplier to a candidate supplier.
    price_discount_threshold: f32 = 0.01,
    /// Monthly probability that a household replaces a supplier that ran
    /// out of inventory during the previous month.
    stockout_rewire_prob: f32 = 0.25,
    /// Maximum number of firms an unemployed household visits when
    /// searching for job openings each month.
    unemployed_search_scope: u32 = 5,
    /// Monthly probability that an employed and satisfied worker searches
    /// for a higher-paying job opening.
    on_the_job_search_prob: f32 = 0.1,
    /// Percentage markdown applied to the reservation wage after a month
    /// of remaining unemployed.
    reservation_wage_markdown: f32 = 0.10,
    /// Shopping stopping threshold: daily shopping ends once this fraction
    /// of daily real demand has been fulfilled.
    satisfaction_threshold: f32 = 0.95,
    /// Initial reservation wage assigned to households at the start of the simulation.
    initial_reservation_wage: Currency = CurrencyOps.to_scaled(1),
    // DERIVE: distribute initial money between all households
    // initial_household_liquidity: Currency = 10000,
};

const Table = std.MultiArrayList(Household);
