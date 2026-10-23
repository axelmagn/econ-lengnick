const std = @import("std");
const units = @import("units.zig");
const Firm = @import("Firm.zig");

const Household = @This();

const Money = units.Money;
const Goods = units.Goods;

liquidity: Money,
/// ω_h: sets job-search intensity and the minimum wage an unemployed
/// household accepts.
reservation_wage: Money,
/// Type-B connection; null when unemployed.
employer: ?Firm.Id = null,
/// ⌊c_h^r / num_days⌋: units to buy each day this month.
daily_demand: Goods,

pub const Id = u32;
pub const Table = std.MultiArrayList(Household);

/// Shared by all households, constant. Values are Table 1 (p.110).
/// Table 1's household φ = 0.25 is used by no rule in the text and is omitted.
pub const Config = struct {
    /// n: type-A (supplier) links per household; also the most firms visited
    /// per day.
    num_goods_links: u32 = 7,
    /// ψ_Price: monthly probability of searching for a cheaper supplier.
    price_search_prob: f64 = 0.25,
    /// ξ: relative price gap needed to switch supplier.
    price_switch_threshold: f64 = 0.01,
    /// ψ_Quant: monthly probability of replacing a supplier that couldn't
    /// meet demand.
    quant_search_prob: f64 = 0.25,
    /// β: most firms an unemployed household visits per month.
    unemployed_search_visits: u32 = 5,
    /// π: monthly probability a satisfied employee checks one random firm.
    satisfied_search_prob: f64 = 0.1,
    /// α: exponent in c_h^r = min{(m_h/P_h^l)^α, m_h/P_h^l}, 0 < α < 1.
    consumption_exponent: f64 = 0.9,
    /// Fraction of daily demand that ends the day's search (p.109).
    satisfaction_fraction: f64 = 0.95,
    /// Reservation-wage cut after a month of unemployment (p.109).
    wage_decay_rate: f64 = 0.1,
};
