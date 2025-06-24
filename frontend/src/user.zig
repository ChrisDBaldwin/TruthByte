const std = @import("std");

// User ID management constants
const USER_ID_LENGTH = 36; // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
const STORAGE_KEY = "truthbyte_user_id";

// Global user ID storage
var user_id_buffer: [USER_ID_LENGTH + 1]u8 = undefined; // +1 for null terminator
var user_id_initialized: bool = false;

// External JavaScript functions for localStorage access (minimal interface)
extern fn js_get_local_storage(key_ptr: [*]const u8, key_len: usize, value_ptr: [*]u8, value_len: usize) i32;
extern fn js_set_local_storage(key_ptr: [*]const u8, key_len: usize, value_ptr: [*]const u8, value_len: usize) void;

// Generate a UUID v4 string
fn generateUUID(prng: *std.Random.DefaultPrng) [USER_ID_LENGTH]u8 {
    var uuid_bytes: [16]u8 = undefined;
    prng.random().bytes(&uuid_bytes);

    // Set version (4) and variant bits for UUID v4
    uuid_bytes[6] = (uuid_bytes[6] & 0x0F) | 0x40; // Version 4
    uuid_bytes[8] = (uuid_bytes[8] & 0x3F) | 0x80; // Variant bits

    var uuid_str: [USER_ID_LENGTH]u8 = undefined;
    _ = std.fmt.bufPrint(&uuid_str, "{x:0>2}{x:0>2}{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{
        uuid_bytes[0],  uuid_bytes[1],  uuid_bytes[2],  uuid_bytes[3],
        uuid_bytes[4],  uuid_bytes[5],  uuid_bytes[6],  uuid_bytes[7],
        uuid_bytes[8],  uuid_bytes[9],  uuid_bytes[10], uuid_bytes[11],
        uuid_bytes[12], uuid_bytes[13], uuid_bytes[14], uuid_bytes[15],
    }) catch unreachable;

    return uuid_str;
}

// Initialize user ID (generate or load from storage)
pub fn initUserID(prng: *std.Random.DefaultPrng) void {
    if (user_id_initialized) return;

    const builtin = @import("builtin");

    // Try to load from localStorage (only in web builds)
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        var temp_buffer: [USER_ID_LENGTH + 1]u8 = undefined;
        const result = js_get_local_storage(STORAGE_KEY.ptr, STORAGE_KEY.len, &temp_buffer, temp_buffer.len);

        if (result > 0 and result <= USER_ID_LENGTH) {
            // Successfully loaded from localStorage
            const result_usize = @as(usize, @intCast(result));
            @memcpy(user_id_buffer[0..result_usize], temp_buffer[0..result_usize]);
            user_id_buffer[result_usize] = 0; // Null terminate
            user_id_initialized = true;

            return;
        }
    }

    // Generate new UUID
    const new_uuid = generateUUID(prng);
    @memcpy(user_id_buffer[0..USER_ID_LENGTH], &new_uuid);
    user_id_buffer[USER_ID_LENGTH] = 0; // Null terminate
    user_id_initialized = true;

    // Save to localStorage (only in web builds)
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        js_set_local_storage(STORAGE_KEY.ptr, STORAGE_KEY.len, &user_id_buffer, USER_ID_LENGTH);
    }
}

// Get the current user ID (must call initUserID first)
pub fn getUserID() [:0]const u8 {
    if (!user_id_initialized) {
        return "";
    }
    return user_id_buffer[0..USER_ID_LENGTH :0];
}

// Get user ID as a slice for API calls
pub fn getUserIDSlice() []const u8 {
    if (!user_id_initialized) {
        return "";
    }
    return user_id_buffer[0..USER_ID_LENGTH];
}

// Reset user ID (for testing or user logout)
pub fn resetUserID() void {
    user_id_initialized = false;
    @memset(&user_id_buffer, 0);
}
