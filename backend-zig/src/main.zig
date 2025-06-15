//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const utils = @import("utils.zig");

pub fn main() !void {
    const input = utils.AnswerInput{
        .user_id = "u001",
        .question_id = "q001",
        .answer = true,
        .timestamp = @as(u64, @intCast(std.time.timestamp())),
    };
    try utils.submit_answers(input);
}
