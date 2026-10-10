//! casting utilities
const std = @import("std");

/// cast between numeric types.
///
/// This function aims to convert between numeric types using the appropriate
/// function that feels intuitive and obvious to the author.  This generally
/// works out to roughly resemble the rules of implicit numeric conversion in
/// C.
///
/// does not accept pointers, as their casting path is often ambiguous.
pub fn num_cast(T: type, value: anytype) T {
    const I = @TypeOf(value);
    const in_info = @typeInfo(I);
    const out_info = @typeInfo(T);
    const comp_err = "cannot num_cast types: " ++ @typeName(I) ++ " -> " ++ @typeName(T);

    return switch (out_info) {
        .int => switch (in_info) {
            .float, .comptime_float => @intFromFloat(value),
            .bool => @intFromBool(value),
            .@"enum" => @intCast(@intFromEnum(value)),
            .error_set => @intCast(@intFromError(value)),
            .int, .comptime_int => @intCast(value),
            else => @compileError(comp_err),
        },
        .float => switch (in_info) {
            .int, .comptime_int => @floatFromInt(value),
            .float, .comptime_float => @floatCast(value),
            .bool => @floatFromInt(@intFromBool(value)),
            .@"enum" => @floatFromInt(@intFromEnum(value)),
            .error_set => @floatFromInt(@intFromError(value)),
            else => @compileError(comp_err),
        },
        .@"enum" => switch (in_info) {
            .enum_literal => @as(T, value),
            .int, .comptime_int, .float, .comptime_float, .bool, .@"enum" => @enumFromInt(num_cast(out_info.@"enum".tag_type, value)),
            else => @compileError(comp_err),
        },
        .bool => switch (in_info) {
            .bool => value,
            .int, .comptime_int => value != 0,
            .float, .comptime_float => value != 0.0,
            .@"enum" => @intFromEnum(value) != 0,
            else => @compileError(comp_err),
        },
        .error_set => switch (in_info) {
            .int, .comptime_int, .@"enum" => @errorCast(@errorFromInt(num_cast(u16, value))),
            .error_set => @errorCast(value),
            else => @compileError(comp_err),
        },
        else => @compileError(comp_err),
    };
}
