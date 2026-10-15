const std = @import("std");
const Allocator = std.mem.Allocator;
const Atomic = std.atomic.Value;
const assert = std.debug.assert;
const log = @import("core.zig").log;
const log_err_default = @import("core.zig").log_err_default;

pub var global = struct {
    proc: std.process.Init,
    io: std.Io = undefined,
    gpa: Allocator = undefined,
    barrier: Barrier = .{},
    num_lanes: u32 = 0,
    lanes: []std.Thread.Id,
}{};

pub threadlocal var ctx = struct {
    arena: Allocator = undefined,
    thread_id: std.Thread.Id = 0,
    lane: u32 = 0,
}{};

pub const Barrier = struct {
    arrived_count: Atomic(u32) align(std.atomic.cache_line) = .init(0),
    generation: Atomic(u32) align(std.atomic.cache_line) = .init(0),

    const max_spins = 128;

    pub fn sync(self: *Barrier, io: std.Io) void {
        assert(global.num_lanes > 0);

        // current generation at start of sync
        const gen = self.generation.load(.acquire);

        // final arrival releases everyone
        const arrived = self.arrived_count.fetchAdd(1, .acq_rel) + 1;
        if (arrived == global.num_lanes) {
            self.arrived_count.store(0, .monotonic);
            self.generation.store(gen +% 1, .release);
            io.futexWake(u32, &self.generation.raw, std.math.maxInt(u32));
            return;
        }

        // spin phase
        for (0..max_spins) |_| {
            if (self.generation.load(.acquire) != gen) return;
            std.atomic.spinLoopHint();
        }

        // sleep phase
        while (self.generation.load(.acquire) == gen) {
            io.futexWaitUncancelable(u32, &self.generation.raw, gen);
        }
    }
};

pub const Parallelism = union(enum) {
    single,
    exact: u32,
    all_cores,

    pub const default: Parallelism = .all_cores;

    pub fn num_lanes(self: Parallelism) u32 {
        return switch (self) {
            .single => 1,
            .exact => |n| n,
            .all_cores => std.Thread.getCpuCount() catch |err| log_err_default(
                "error while getting CPU count: {any} (defaulting to 1)",
                .{err},
                1,
            ),
        };
    }
};

pub fn launch(proc: std.process.Init, comptime entrypoint: anytype, args: anytype, parallelism: Parallelism) !void {
    global.proc = proc;
    global.gpa = proc.gpa;
    global.num_lanes = parallelism.num_lanes();
}

fn thread_launch(comptime entrypoint: anytype, args: anytype, lane: u32, arena: Allocator) !void {
    ctx.arena = arena;
    ctx.thread_id = std.Thread.getCurrentId();
    ctx.lane = lane;
    try @call(.auto, entrypoint, args);
}
