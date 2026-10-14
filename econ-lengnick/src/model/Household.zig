const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const assert = @import("std").debug.assert;

const Currency = @import("units.zig").Currency;
const Goods = @import("units.zig").Goods;
const Firm = @import("Firm.zig");

const Household = @This();

liquidity: Currency,
reservation_wage: Currency,
employer: ?Firm.Id,
planned_consumption: Goods,

// intrusive list: employer's employees
employees_next: ?Household.Id,

// related:
// suppliers - separate table
// shortfalls - part of suppliers table

pub const Id = usize;
pub const Table = std.MultiArrayList(@This());

pub const Config = struct {
    num_households: usize = 1000,
    max_suppliers: usize = 7,
    price_search_prob: f32 = 0.25,
    price_switch_threshold: f32 = 0.01,
    demand_search_prob: f32 = 0.25,
    unemployed_search_visits: usize = 5,
    satisfied_search_prob: f32 = 0.1,
    consumption_exp: f32 = 0.9,
};

/// calculate the average supplier price and number of suppliers for every household.
fn calc_supplier_avg_prices_and_counts(
    firm_prices: []const Currency,
    suppliers: []const Firm.Id,
    customers: []const Household.Id,
    avg_prices_out: []Currency,
    counts_out: []u8,
) void {
    assert(suppliers.len == customers.len);
    assert(avg_prices_out.len == counts_out.len);
    const num_households = avg_prices_out.len;
    @memset(avg_prices_out, Currency.zero);
    @memset(counts_out, 0);
    for (suppliers, customers) |supplier, customer| {
        assert(supplier < firm_prices.len);
        assert(customer < num_households);
        const price = firm_prices[supplier];
        avg_prices_out[customer] = avg_prices_out[customer].add(price);
        counts_out[customer] += 1;
    }
    for (0..num_households) |i| {
        const count = counts_out[i];
        if (count == 0) continue;
        avg_prices_out[i] = avg_prices_out[i].div(count);
    }
}

test calc_supplier_avg_prices_and_counts {
    const num_firms = 10;
    const num_households = 100;
    const num_suppliers = 5;
    const num_links = num_suppliers * num_households;
    const flat_price = Currency.from(3);

    const firm_prices: [num_firms]Currency = @splat(flat_price);
    var counts_expected: [num_households]u8 = @splat(0);

    var suppliers: [num_links]Firm.Id = undefined;
    var customers: [num_links]Household.Id = undefined;
    for (0..num_links) |i| {
        suppliers[i] = 1 + (i % (num_firms - 1));
        customers[i] = 1 + (i % (num_households - 1));
        counts_expected[customers[i]] += 1;
    }

    var avg_prices: [num_households]Currency = undefined;
    var counts: [num_households]u8 = undefined;
    calc_supplier_avg_prices_and_counts(
        &firm_prices,
        &suppliers,
        &customers,
        &avg_prices,
        &counts,
    );

    for (0..num_households) |i| {
        try std.testing.expectEqual(flat_price, avg_prices[i]);
        try std.testing.expectEqual(counts_expected[i], counts[i]);
    }
}
