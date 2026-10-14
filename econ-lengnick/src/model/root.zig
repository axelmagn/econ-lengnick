const std = @import("std");
pub const Household = @import("Household.zig");

test {
    std.testing.refAllDecls(Household);
}
