const rl = @import("raylib");
const std = @import("std");
const game = @import("game.zig");
const utils = @import("utils.zig");
const types = @import("types.zig");

pub fn main() !void {
    // Don't use fullscreen mode for better mobile compatibility
    const size = utils.get_canvas_size();
    rl.initWindow(size.w, size.h, "TruthByte");
    std.debug.print("Screen resolution (from canvas): {}x{}\n", .{ size.w, size.h });
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // Confirm rendering resolution
    const screen_width = utils.get_canvas_size().w;
    const screen_height = utils.get_canvas_size().h;
    std.debug.print("Screen resolution: {}x{}\n", .{ screen_width, screen_height });

    var allocator = std.heap.c_allocator;
    const raw = game.init(&allocator);
    const state: *types.GameState = @ptrCast(@alignCast(raw));

    while (!rl.windowShouldClose()) {
        game.update(state);
        game.draw(state);
    }

    game.deinit(&allocator, state);
}
