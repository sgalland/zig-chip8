const std = @import("std");
const Allocator = std.mem.Allocator;

// Normally user programs are loaded at address 0x200.
// On ETI machines memory starts at 0x600.
// NOTE: Does anyone try to even emulate ETI?
const USER_MEMORY_ADDRESS = 0x200;
const ETI_USER_MEMORY_ADDRESS = 0x600;
const FONT_ADDRESS = 0x50;

pub const DISPLAY_WIDTH = 64;
pub const DISPLAY_HEIGHT = 32;

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
    random: std.rand.Random,

    // CHIP8 internals
    memory: [4096]u8 = [_]u8{0} ** 4096,
    registers: [16]u8 = [_]u8{0} ** 16,
    delay_timer: u8 = 0,
    sound_timer: u8 = 0,
    index_register: u16 = 0,
    program_counter: u16 = USER_MEMORY_ADDRESS,
    stack_pointer: u16 = 0,
    stack: [16]u16 = [_]u16{0} ** 16,
    keyboard: [16]u8 = [_]u8{0} ** 16,
    video: [DISPLAY_WIDTH * DISPLAY_HEIGHT]u32 = [_]u32{0} ** (DISPLAY_WIDTH * DISPLAY_HEIGHT),

    // Emulator internals
    last_timestamp: u64 = 0,

    pub fn init(allocator: Allocator, random: std.rand.Random) Chip8 {
        return Chip8{
            .allocator = allocator,
            .random = random,
        };
    }

    // Clears memory and loads ROM into memory. Sets the Program Counter to the start of user addressable memory.
    pub fn loadRom(self: *Self, filename: []const u8) !void {
        const stat = try std.fs.cwd().statFile(filename);
        const data = try std.fs.cwd().readFileAlloc(self.allocator, filename, stat.size);
        defer self.allocator.free(data);

        std.mem.copyForwards(u8, self.memory[FONT_ADDRESS..], &FONTS);
        std.mem.copyForwards(u8, self.memory[USER_MEMORY_ADDRESS..], data);

        self.program_counter = USER_MEMORY_ADDRESS;
    }

    pub fn cycle(self: *Self, current_timestamp: u64) void {
        // Timers decrement at a rate of 60 times per second (every 16.66666666ms).
        // If value of the timer is greater than 0, decrement it
        const cycle_speed = std.time.ms_per_s / 60;
        if (current_timestamp - self.last_timestamp > cycle_speed) {
            if (self.delay_timer > 0) self.delay_timer -= 1;
            if (self.sound_timer > 0) self.sound_timer -= 1;

            self.last_timestamp = current_timestamp;

            // Fetch the next instruction and increment the program counter.
            const instruction: u16 = @as(u16, self.memory[self.program_counter]) << 8 | self.memory[self.program_counter + 1];
            self.program_counter += 2;

            // Decode instructions
            const code: u16 = (instruction & 0xF000);
            const x: u8 = @truncate(u8, instruction) & 0x0F00 >> 8;
            const y: u8 = @truncate(u8, instruction) & 0x00F0 >> 4;
            const n: u8 = @truncate(u8, instruction) & 0x000F;
            const nn: u8 = @truncate(u8, instruction) & 0x00FF;
            const nnn: u16 = instruction & 0x0FFF;

            std.debug.print(">> code={X}, x={X}, y={X}, n={X}, nn={X}, nnn={X}\n", .{ code, x, y, n, nn, nnn });

            // Execute instructions
            // The comments below are taken from Cowgod's Chip-8 technical reference
            // See: http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#00E0
            switch (code) {
                0x0000 => switch (n) {
                    // 00E0 - CLS
                    0x00 => @memset(&self.video, 0),
                    // 00EE - RET
                    // 0x0E => {
                    //     self.program_counter = self.stack[self.stack_pointer];
                    //     if (self.stack_pointer > 0)
                    //         self.stack_pointer -= 1;
                    // },
                    else => unreachable,
                },
                // 1nnn - JP addr
                0x1000 => self.program_counter = nnn,
                // 2nnn - CALL addr
                // 0x2000 => {
                //     self.stack_pointer += 1;
                //     self.stack[self.stack_pointer] = self.program_counter;
                //     self.program_counter = nnn;
                // },
                // 3xkk - Skip next instruction V[x] = kk
                // 0x3000 => {
                //     if (self.registers[x] == nn) {
                //         self.program_counter += 2;
                //     }
                // },
                // 4xkk - Skip next instruction V[x] != kk
                // 0x4000 => {
                //     if (self.registers[x] != nn) {
                //         self.program_counter += 2;
                //     }
                // },
                // 5xy0 - Skip next instruction Vx = Vy
                // 0x5000 => {
                //     if (self.registers[x] == self.registers[y]) {
                //         self.program_counter += 2;
                //     }
                // },
                // 6xkk - Set register Vx = kk
                0x6000 => self.registers[x] = nn,
                // 7xkk - Add value to register
                0x7000 => self.registers[x] += nn,
                // Annn - LD. Set I = nnn.
                0xA000 => self.index_register = nnn,

                // DXYN - Display n-byte sprite at memory location I at (Vx, Vy), set VF = collision.
                0xD000 => {
                    const x_pos: u8 = self.registers[x] % DISPLAY_WIDTH;
                    const y_pos: u8 = self.registers[y] % DISPLAY_HEIGHT;

                    self.registers[0xF] = 0; // clear the collision flag

                    for (0..n) |row| {
                        const sprite_byte = self.memory[self.index_register + row];

                        for (0..8) |col| {
                            const sprite_pixel: u8 = sprite_byte & std.math.shr(u8, 0x80, col);
                            const screen_pixel: *u32 = &self.video[(y_pos + row) * DISPLAY_WIDTH + (x_pos + col)];

                            if (sprite_pixel != 0) {
                                if (screen_pixel.* == 0xFFFFFFFF) {
                                    self.registers[0xF] = 1;
                                }

                                screen_pixel.* ^= 0xFFFFFFFF;
                            }
                        }
                    }
                },
                // Use std.debug.print(">> code={X}, x={X}, y={X}, n={X}, nn={X}, nnn={X}\n", .{ code, x, y, n, nn, nnn })
                // to determine what instructions are missing.
                else => std.debug.print(">> code={X}, x={X}, y={X}, n={X}, nn={X}, nnn={X} <<\n", .{ code, x, y, n, nn, nnn }),
                //unreachable,
            }
        }
    }
};
