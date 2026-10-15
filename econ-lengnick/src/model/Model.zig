const std = @import("std");
const Firm = @import("Firm.zig");
const Household = @import("Household.zig");
const SupplierLink = @import("SupplierLink.zig");
const log = @import("core.zig").log;

const Model = @This();

day: usize = 0,
firms: Firm.Table = .empty,
households: Household.Table = .empty,
supplier_links: SupplierLink.Table = .empty,

const Config = struct {
    days_per_month: usize = 21,
    months_per_year: usize = 12,

    firm: Firm.Config,
    household: Household.Config,
};

const Runner = struct {
    model: *Model,
    config: *const Config,

    pub fn reset(self: *const Runner) void  {
        self.model.day = 0;
    }

    pub fn step(self: *const Runner) !void {
        const day_of_month = @mod(self.model.day, self.config.days_per_month);

        if (day_of_month == 0) try self.step_month_start();
        try self.step_day();
        if (day_of_month == self.config.days_per_month - 1) {
            try self.step_month_start();
        }

        self.model.day += 1;
    }

    fn step_month_start(self: *const Runner) !void {
        log.debug("[{d:9}] month start", .{self.model.day});
    }

    fn step_month_end(self: *const Runner) !void {
        log.debug("[{d:9}] month end", .{self.model.day});
    }

    fn step_day(self: *const Runner) !void {
        log.debug("[{d:9}]", .{self.model.day});
    }
};
