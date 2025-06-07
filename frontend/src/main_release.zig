const rl = @import("raylib");
const std = @import("std");
const game = @import("game.zig");

pub fn main() !void {
    rl.setConfigFlags(.{ .FLAG_FULLSCREEN_MODE = true });
    rl.initWindow(0, 0, "TruthByte");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // Confirm rendering resolution
    const screen_width = rl.getScreenWidth();
    const screen_height = rl.getScreenHeight();
    std.debug.print("Screen resolution: {}x{}\n", .{ screen_width, screen_height });

    var allocator = std.heap.c_allocator;
    const state: *game.GameState = @ptrCast(@alignCast(game.init(&allocator)));

    while (!rl.windowShouldClose()) {
        game.update(state);
        game.draw(state);
    }

    game.deinit(&allocator, state);
}
