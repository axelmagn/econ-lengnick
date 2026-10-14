const std = @import("std");

/// Quantity of real consumption goods and warehouse inventory units.
pub const Goods = i32;
/// Nominal currency amount used as the medium of exchange.
pub const Currency = ScaledNum(i32, 1000);

/// position in world coordinates
pub const Position = @Vector(2, i32);

fn ScaledNum(T: type, scale_: T) type {
    comptime {
        std.debug.assert(@typeInfo(T) == .int);
    }
    return struct {
        scaled_value: T,

        pub const scale = scale_;
        const Self = @This();

        const inner_ops = struct {
            pub fn add_(lhs: T, rhs: T) T {
                return lhs + rhs;
            }

            pub fn sub_(lhs: T, rhs: T) T {
                return lhs - rhs;
            }

            pub fn mul_(lhs: T, rhs: T) T {
                return @divTrunc(lhs * rhs, scale);
            }

            pub fn div_(lhs: T, rhs: T) T {
                return scale * @divTrunc(lhs, rhs);
            }
        };

        pub const zero = Self.from(0);
        pub const one = Self.from(1);
        pub const add = map_op(inner_ops.add_);
        pub const sub = map_op(inner_ops.sub_);
        pub const div = map_op(inner_ops.div_);

        pub inline fn from(value: anytype) Self {
            const V = @TypeOf(value);
            const v_info = @typeInfo(V);
            const scaled_value: T = switch (v_info) {
                .int, .comptime_int => @as(T, @intCast(value)) * scale,
                .float, .comptime_float => @as(T, @intFromFloat(value * @as(V, scale))),
                else => @compileError("unsupported value type: " ++ @typeName(V)),
            };
            return .{ .scaled_value = scaled_value };
        }

        /// Wraps a value that is already in scaled representation.
        fn from_scaled(value: T) Self {
            return .{ .scaled_value = value };
        }

        fn to_float(self: Self, F: type) F {
            return @as(F, self.scaled_value) / @as(F, scale);
        }

        // pub fn mul_float(lhs: Self, rhs: anytype) Self {
        //     return from_scaled(inner_ops.mul_float_(lhs.scaled_value, rhs));
        // }

        fn map_op(op: fn (T, T) T) fn (Self, anytype) Self {
            return struct {
                fn f(lhs: Self, rhs: anytype) Self {
                    const R = @TypeOf(rhs);
                    const rhs_: Self = if (R == Self) rhs else .from(rhs);
                    return from_scaled(op(lhs.scaled_value, rhs_.scaled_value));
                }
            }.f;
        }

        pub fn mul(lhs: Self, rhs: anytype) Self {
            const R = @TypeOf(rhs);
            if (R == Self) {
                return from_scaled(@divTrunc(
                    lhs.scaled_value * rhs.scaled_value,
                    scale,
                ));
            }
            const scaled_value: T = switch (@typeInfo(R)) {
                .int, .comptime_int => lhs.scaled_value * R,
                .float, .comptime_float => @intFromFloat(@as(f64, lhs.scaled_value) *
                    @as(f64, @floatCast(rhs))),
                else => @compileError("unsupported type: " ++ @typeName(R)),
            };
            return .{ .scaled_value = scaled_value };
        }
    };
}

test ScaledNum {
    const C = Currency; // ScaledNum(i32, 1000): 1000 units == 1.0

    const two = C.from(2); // 2.0
    try std.testing.expectEqual(2000, two.scaled_value);
    const three = C.from(3); // 3.0
    try std.testing.expectEqual(3000, three.scaled_value);

    // add/sub act on the raw scaled values
    try std.testing.expectEqual(C.from(5), two.add(three));
    try std.testing.expectEqual(C.from(-1), two.sub(three));

    // mul compensates for scale: 2.0 * 3.0 == 6.0
    try std.testing.expectEqual(C.from(6), two.mul(three));

    // div compensates for scale: 6.0 / 2.0 == 3.0
    try std.testing.expectEqual(three, C.from(6).div(two));

    // mul_float rounds the factor to the nearest scaled unit: 2.0 * 1.5 == 3.0
    try std.testing.expectEqual(three, two.mul(1.5));
}
