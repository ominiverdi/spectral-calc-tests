const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    
    // Use ReleaseFast mode for maximum speed
    const optimize = b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Optimization mode",
    ) orelse .ReleaseFast;

    const exe = b.addExecutable(.{
        .name = "ndvi_calculator",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link GDAL libraries
    exe.linkSystemLibrary("gdal");
    exe.linkSystemLibrary("c");
    
    // Add native CPU optimization flags
    exe.addCSourceFile(.{
        .file = .{ .path = "src/empty.c" },
        .flags = &[_][]const u8{"-march=native"},
    });
    
    // Use single-threaded mode for runtime components
    // (This doesn't affect our manual threading)
    exe.single_threaded = true;
    
    // Strip debug symbols for smaller binary
    exe.strip = true;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the NDVI calculator");
    run_step.dependOn(&run_cmd.step);
}