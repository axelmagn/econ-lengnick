const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Modules reach each other through the module graph rather than by relative path.
    const base = b.createModule(.{
        .root_source_file = b.path("src/base/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const sim = b.createModule(.{
        .root_source_file = b.path("src/sim/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "base", .module = base }},
    });

    const test_step = b.step("test", "Run unit tests for every module");
    const modules = [_]struct { name: []const u8, module: *std.Build.Module }{
        .{ .name = "base", .module = base },
        .{ .name = "sim", .module = sim },
    };
    for (modules) |entry| {
        const run = b.addRunArtifact(b.addTest(.{ .root_module = entry.module }));
        const step_name = b.fmt("test-{s}", .{entry.name});
        const step_description = b.fmt("Run unit tests for {s}", .{entry.name});
        b.step(step_name, step_description).dependOn(&run.step);
        test_step.dependOn(&run.step);
    }
}
