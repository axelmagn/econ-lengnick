const std = @import("std");

pub fn impl(Sig: type, Impl: type) Sig {
    const sig_info: std.lang.Type = @typeInfo(Sig);
    var result: Sig = undefined;
    inline for (sig_info.@"struct".field_names) |field| {
        @field(result, field) = @field(Impl, field);
    }
    return result;
}

pub fn Num(T: type) type {
    return struct {
        zero: T,
        one: T,

        add: fn (T, T) T,
        sub: fn (T, T) T,
        mul: fn (T, T) T,
        div: fn (T, T) T,
    };
}
