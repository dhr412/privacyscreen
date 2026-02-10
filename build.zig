const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 },
    });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "privscrn",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/privscrn.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("user32");
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
