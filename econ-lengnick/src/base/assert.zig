const std = @import("std");

/// Wraps the standard assert so the assertion policy can change in one place.
/// Being an ordinary function, it also works in `comptime` blocks.
pub fn assert(ok: bool) void {
    std.debug.assert(ok);
}
