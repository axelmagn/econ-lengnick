const std = @import("std");

pub const log = std.log.scoped(.lengnick_model);

/// utility function: log an error and return a default value
pub fn log_err_default(
    format: []const u8,
    args: anytype,
    value: anytype,
) @TypeOf(value) {
    log.err(format, args);
    return value;
}
