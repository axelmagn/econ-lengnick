const std = @import("std");

pub const Model = @import("Model.zig");
const Household = @import("Household.zig");
const thread = @import("thread.zig");

test {
    std.testing.refAllDecls(Household);
    std.testing.refAllDecls(thread);
}
