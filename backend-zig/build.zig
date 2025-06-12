const std = @import("std");
const aws_lambda = @import("aws_lambda");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    // Add an architecture CLI option (or hard code either `.x86` or `.arm`)
    const arch: aws_lambda.Arch = aws_lambda.archOption(b);

    // Managed architecture target resolver
    const target = aws_lambda.resolveTargetQuery(b, arch);

    // We will also create a module for our other entry point, 'main.zig'.
    const exe = b.addExecutable(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .name = "bootstrap", // This is the name of the executable and it must be 'bootstrap'
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // .link_libc = true, // Uncomment if glibc is required.
        // .strip = true, // Uncomment if no stack traces are needed.
    });
    b.installArtifact(exe);

    exe.root_module.addImport(
        "aws_lambda",
        b.createModule(.{ .root_source_file = b.path("aws_lambda.zig") }),
    );

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
