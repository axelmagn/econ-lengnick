//! Test root: pulls every module with tests into the test build.
//! Run with `zig build test`.

const std = @import("std");

test {
    // TODO: ref all decls?
    _ = @import("model/units.zig");
    _ = @import("model/Firm.zig");
}
