const std = @import("std");
const Allocator = std.mem.Allocator;

// Normally user programs are loaded at address 0x200.
// On ETI machines memory starts at 0x600.
const USER_MEMORY_ADDRESS = 0x200;
const ETI_USER_MEMORY_ADDRESS = 0x600;

const FONTS = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

pub const Chip8 = struct {
    const Self = @This();

    allocator: Allocator,

    // CHIP8 internals
    memory: [4096]u8 = [_]u8{0} ** 4096,
    registers: [16]u8 = [_]u8{0} ** 16,
    delay_timer: u8 = 0,
    sound_timer: u8 = 0,
    index_register: u16 = 0,
    program_counter: u16 = 0,
    stack_pointer: u16 = 0,
    stack: [16]u16 = [_]u16{0} ** 16,
    keyboard: [16]u8 = [_]u8{0} ** 16,
    video: [64 * 32]u32 = [_]u32{0} ** (64 * 32),

    // Emulator internals
    last_timestamp: u64 = 0,

    pub fn init(allocator: Allocator) Chip8 {
        return Chip8{
            .allocator = allocator,
        };
    }

    // Load a ROM into memory.
    pub fn loadRom(self: *Self, filename: []const u8) void {
        const stat = try std.fs.cwd().statFile(filename);
        const data = try std.fs.cwd().readFileAlloc(self.allocator, filename, stat.size);

        std.mem.copyForwards(u8, self.memory[USER_MEMORY_ADDRESS..], data);
    }

    pub fn cycle(self: *Self, current_timestamp: u64) void {
        // Timers decrement at a rate of 60 times per second (every 16.66666666ms).
        // If value of the timer is greater than 0, decrement it
        if (current_timestamp - self.last_timestamp > 16_666_666) {
            if (self.delay_timer > 0) self.delay_timer -= 1;
            if (self.sound_timer > 0) self.sound_timer -= 1;

            self.last_timestamp = current_timestamp;
        }

        // Read instructions, each instruction is two bytes long.
    }
};

fn dispatch(code: u8) void {
    switch (code) {
        0x00E0 => chip8_inst_cls(),
        0x00EE => chip8_inst_ret(),
    }
}

/// Clear the display by setting all pixels to ‘off’.
fn chip8_inst_cls() void {}

/// Return from a subroutine. Pops the value at the top of the stack (indicated by the stack pointer SP) and puts it in PC.
fn chip8_inst_ret() void {}
