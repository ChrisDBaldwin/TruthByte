// backend/src/utils.zig

const std = @import("std");

pub const AnswerInput = struct {
    user_id: []const u8,
    question_id: []const u8,
    answer: bool,
    timestamp: u64,
};

pub fn submit_answers(input: AnswerInput) !void {
    // placeholder logic
    std.debug.print("Saving answer from user {s} on question {s}: {}\n", .{ input.user_id, input.question_id, input.answer });

    // here you'd eventually insert into DynamoDB
    // const db = std.mem.Allocator.init(std.heap.page_allocator);
    // const table_name = "answers";
    // const key = .{ .user_id = input.user_id, .question_id = input.question_id };
    // const item = .{ .answer = input.answer, .timestamp = input.timestamp };
    // const put_item_input = .{ .table_name = table_name, .key = key, .item = item };

}
