const std = @import("std");
const rlz = @import("raylib_zig");

const Context = struct {
    raylib: *std.Build.Module,
    raygui: *std.Build.Module,
    raylib_artifact: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const is_wasm = target.result.cpu.arch.isWasm();

    if (is_wasm and b.sysroot == null) {
        const emsdk_root = std.process.getEnvVarOwned(b.allocator, "EMSDK") catch null;
        if (emsdk_root) |p| {
            b.sysroot = try std.fs.path.join(b.allocator, &.{ p, "upstream", "emscripten" });
        } else {
            std.debug.print("error: EMSDK not set and no sysroot specified.\n", .{});
            return error.MissingEmscripten;
        }
    }

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .shared = target.query.os_tag != .emscripten,
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const context = Context{
        .raylib = raylib,
        .raygui = raygui,
        .raylib_artifact = raylib_artifact,
        .optimize = optimize,
        .target = target,
    };

    try build_hot(b, context);

    if (is_wasm) {
        try build_web(b, context);
    } else {
        try build_native(b, context);
    }
}

fn build_native(
    b: *std.Build,
    ctx: Context,
) !void {
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main_hot.zig"), // swap to main_release for release
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libc = true,
    });

    exe_mod.addImport("raylib", ctx.raylib);
    exe_mod.addImport("raygui", ctx.raygui);

    const exe = b.addExecutable(.{
        .name = "TruthByte",
        .root_module = exe_mod,
    });

    exe.linkLibrary(ctx.raylib_artifact);
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn build_web(
    b: *std.Build,
    ctx: Context,
) !void {
    const exe_lib = try rlz.emcc.compileForEmscripten(b, "game", "src/main_release.zig", ctx.target, ctx.optimize);
    exe_lib.root_module.link_libc = true;
    exe_lib.linkLibrary(ctx.raylib_artifact);
    exe_lib.root_module.addImport("raylib", ctx.raylib);
    exe_lib.root_module.addImport("raygui", ctx.raygui);

    const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, ctx.raylib_artifact });

    // -----------------------------------------------------------------------
    // Embed resources such as textures and fonts so they are available at runtime
    link_step.addArg("--embed-file");
    link_step.addArg("res/");
    // -----------------------------------------------------------------------

    link_step.addArg("--shell-file");
    link_step.addArg("shell.html");
    link_step.addArg("-sERROR_ON_UNDEFINED_SYMBOLS=0");
    link_step.addArg("--js-library");
    link_step.addArg("truthbyte_bindings.js");

    b.getInstallStep().dependOn(&link_step.step);
    const run_step = try rlz.emcc.emscriptenRunStep(b);
    run_step.step.dependOn(&link_step.step);
    const run_option = b.step("run", "Run 'ray_play");
    run_option.dependOn(&run_step.step);
}

fn build_hot(
    b: *std.Build,
    ctx: Context,
) !void {
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "game",
        .root_module = b.createModule(.{
            .target = ctx.target,
            .optimize = ctx.optimize,
            .root_source_file = b.path("src/game.zig"),
            .imports = &.{
                .{ .name = "raylib", .module = ctx.raylib },
                .{ .name = "raygui", .module = ctx.raygui },
            },
        }),
    });

    lib.linkLibrary(ctx.raylib_artifact);
    const lib_install = b.addInstallArtifact(lib, .{});
    const step = b.step("hot", "build lib");
    step.dependOn(&lib_install.step);
}
