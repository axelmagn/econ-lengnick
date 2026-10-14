const std = @import("std");

var b: *std.Build = undefined;
var target: std.Build.ResolvedTarget = undefined;
var optimize: std.builtin.Optimize = undefined;

pub fn build(b_: *std.Build) void {
    b = b_;
    target = b.standardTargetOptions(.{});
    optimize = b.standardOptimizeOption(.{});

    const stdx_mod = build_mod("stdx");

    const model_mod = build_mod("model");
    model_mod.addImport("stdx", stdx_mod);

    const test_step = b.step("test", "run unit tests");
    test_step.dependOn(&b.addTest(.{ .root_module = model_mod }).step);
}

fn build_mod(comptime name: []const u8) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("src/" ++ name ++ "/root.zig"),
        .target = target,
        .optimize = optimize,
    });
}
