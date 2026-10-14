const std = @import("std");
const Goods = @import("units.zig").Goods;
const Firm = @import("Firm.zig");
const Household = @import("Household.zig");

supplier: Firm.Id,
customer: Household.Id,
shortfalls: Goods,


pub const Table = std.MultiArrayList(@This());
