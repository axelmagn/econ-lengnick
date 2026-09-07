const std = @import("std");

/// Quantity of real consumption goods and warehouse inventory units.
const Goods = u32;
/// Nominal currency amount used as the medium of exchange.
const Currency = i32;

const currency_resolution = 1000;

/// Central macroeconomic model state and global configuration.
const Model = struct {
    // TODO: model state

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
        total_money_stock: Currency = 100_000 * currency_resolution,

        /// reference to first employee in intrusive linked list
        employees_head: Household.Id,
    };
};

/// Household agent that supplies labor, earns wages and profit shares, and purchases goods.
const Household = struct {
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
        initial_reservation_wage: Currency = 1 * currency_resolution,
        // DERIVE: distribute initial money between all households
        // initial_household_liquidity: Currency = 10000, 
    };
};

/// Firm agent that hires workers, produces goods, manages inventory, sets
/// prices and wages, and distributes profits.
const Firm = struct {
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
    unfilled_positions_last_month: bool,
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
        initial_wage: Currency = 1 * currency_resolution,
        // initial_workers_per_firm: u32 = 10, // DERIVE: distribute workers for 100% employment
        /// Initial price markup percentage above marginal cost at the start of the simulation.
        initial_price_markup: f32 = 0.10,
        // initial_inventory: Goods = 630, // DERIVE: exactly 1 month of normal production
        // initial_demand_history: Goods = 630 // DERIVE: exactly 1 month of normal production
        // initial_consecutive_full: u32 = 24 // DERIVE: same as employment memory
    };
};


// TODO: supplier relation

// TODO: constrained firm relation
