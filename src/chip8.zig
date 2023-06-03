const std = @import("std");
const Allocator = std.mem.Allocator;

const Chip8 = struct {
    allocator: Allocator,
    data: []u8,

    memory: [4096]u8,
    registers: [16]u8,
    delay_timer: u8,
    sound_timer: u8,
    index_register: u16,
    program_counter: u16,
    stack_pointer: u16,
    stack: [16]u16,
    keyboard: [16]u8,
    video: [64 * 32]u32,

    pub fn init(self: Chip8, allocator: Allocator) void {
        self.allocator = allocator;
    }

    pub fn loadRom(filename: []const u8) void {
        _ = filename;
    }
};
