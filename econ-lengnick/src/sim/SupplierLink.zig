const std = @import("std");
const Firm = @import("Firm.zig");
const Household = @import("Household.zig");
const units = @import("units.zig");

const Goods = units.Goods;

const SupplierLink = @This();


firm: Firm.Id,
household: Household.Id,
/// This month's stock-limited purchases; read by the quantity search, then
/// cleared at the start of the month.
shortfall: Goods,


pub const Id =  u32;
pub const Table = std.MultiArrayList(SupplierLink);
