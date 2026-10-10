//! Central macroeconomic model state and global configuration.
const Firm = @import("Firm.zig");
const Household = @import("Household.zig");
const Currency = @import("units.zig").Currency;

firms: Firm.Table = .empty,
households: Household.Table = .empty,

/// Global model parameters and calibration settings.
const Config = struct {
    /// Total number of household agents in the economy, each inelastically
    /// supplying one unit of labor.
    num_households: u32 = 1000,
    /// Total number of firm agents in the economy.
    num_firms: u32 = 100,
    /// Number of business trading days per macroeconomic planning month.
    days_per_month: u32 = 21,
    /// Total duration of the simulation in months recorded after the burn-in period.
    simulation_horizon_months: u32 = 6000,
    /// Number of initial startup months discarded before collecting simulation data.
    burn_in_months: u32 = 1000,
    /// Total fixed money supply circulating throughout the closed economy.
    total_money_stock: Currency = .from(100_000),
    /// reference to first employee in intrusive linked list
    employees_head: Household.Id = 0,
};
