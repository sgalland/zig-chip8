const std = @import("std");
const engine = @import("engine.zig");
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
    last_instruction_timestamp: u64 = 0,
    event: *engine.Event,
    cycle_speed: u16 = 700,

    pub fn init(allocator: Allocator, random: std.rand.Random, event: *engine.Event) Chip8 {
        return Chip8{ .allocator = allocator, .random = random, .event = event };
    }

    // Clears memory and loads ROM into memory. Sets the Program Counter to the start of user addressable memory.
    pub fn loadRom(self: *Self, filename: []const u8, cycle_speed: ?u16) !void {
        const stat = try std.fs.cwd().statFile(filename);
        const data = try std.fs.cwd().readFileAlloc(self.allocator, filename, stat.size);
        defer self.allocator.free(data);

        std.mem.copyForwards(u8, self.memory[FONT_ADDRESS..], &FONTS);
        std.mem.copyForwards(u8, self.memory[USER_MEMORY_ADDRESS..], data);

        if (cycle_speed) |c| self.cycle_speed = c;
        self.program_counter = USER_MEMORY_ADDRESS;
    }

    // Executes the interpreter at a rate of 60 timers per second. Must in in a loop outside of this function.
    pub fn cycle(self: *Self, current_timestamp: u64) void {
        // Timers decrement at a rate of 60 times per second (every 16.66666666ms).
        // If value of the timer is greater than 0, decrement it
        const cycle_speed = std.time.ms_per_s / 60;
        if (current_timestamp - self.last_timestamp > cycle_speed) {
            if (self.delay_timer > 0) self.delay_timer -= 1;
            if (self.sound_timer > 0) self.sound_timer -= 1;

            self.last_timestamp = current_timestamp;
        }

        const instruction_speed = std.time.ms_per_s / self.cycle_speed;
        if (current_timestamp - self.last_instruction_timestamp > instruction_speed) {
            self.last_instruction_timestamp = current_timestamp;

            // Fetch the next instruction and increment the program counter.
            const instruction: u16 = @as(u16, self.memory[self.program_counter]) << 8 | self.memory[self.program_counter + 1];
            self.program_counter += 2;

            // Decode instructions
            const code: u16 = (instruction & 0xF000);
            const x: u8 = @intCast(u8, @shrExact(instruction & 0x0F00, 8));
            const y: u8 = @intCast(u8, @shrExact(instruction & 0x00F0, 4));
            const n: u8 = @intCast(u8, instruction & 0x000F);
            const nn: u8 = @intCast(u8, instruction & 0x00FF);
            const nnn: u16 = instruction & 0x0FFF;

            // Execute instructions
            // The comments below are taken from Cowgod's Chip-8 technical reference
            // See: http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#00E0
            switch (code) {
                0x0000 => switch (n) {
                    // 00E0 - CLS
                    0x00 => @memset(&self.video, 0),
                    // 00EE - RET
                    0x0E => {
                        self.program_counter = self.stack[self.stack_pointer];
                        if (self.stack_pointer > 0)
                            self.stack_pointer -= 1;
                    },
                    else => unreachable,
                },
                // 1nnn - JP addr
                0x1000 => self.program_counter = nnn,
                // 2nnn - CALL addr
                0x2000 => {
                    self.stack_pointer += 1;
                    self.stack[self.stack_pointer] = self.program_counter;
                    self.program_counter = nnn;
                },
                // 3xkk - Skip next instruction V[x] = kk
                0x3000 => {
                    if (self.registers[x] == nn) {
                        self.program_counter += 2;
                    }
                },
                // 4xkk - Skip next instruction V[x] != kk
                0x4000 => {
                    if (self.registers[x] != nn) {
                        self.program_counter += 2;
                    }
                },
                // 5xy0 - Skip next instruction Vx = Vy
                0x5000 => {
                    if (self.registers[x] == self.registers[y]) {
                        self.program_counter += 2;
                    }
                },
                // 6xkk - Set register Vx = kk
                0x6000 => self.registers[x] = nn,
                // 7xkk - Add value to register
                0x7000 => self.registers[x] = @addWithOverflow(self.registers[x], nn)[0],
                0x8000 => {
                    switch (n) {
                        // 8xy0 - LD Vx, Vy
                        0x00 => self.registers[x] = self.registers[y],
                        // 8xy1 - OR Vx, Vy
                        0x01 => self.registers[x] |= self.registers[y],
                        // 8xy2 - AND Vx, Vy
                        0x02 => self.registers[x] &= self.registers[y],
                        // 8xy3 - XOR Vx, Vy
                        0x03 => self.registers[x] ^= self.registers[y],
                        // 8xy4 - ADD Vx, Vy. If overflow set 0x0F
                        0x04 => {
                            const addOp = @addWithOverflow(self.registers[x], self.registers[y]);
                            self.registers[x] = addOp[0];
                            self.registers[0x0F] = addOp[1];
                        },
                        // 8xy5 - SUB Vx, Vy
                        0x05 => {
                            self.registers[0x0F] = if (self.registers[x] > self.registers[y]) 1 else 0;
                            const subOp = @subWithOverflow(self.registers[x], self.registers[y]);
                            self.registers[x] = subOp[0];
                        },
                        // 8xy6 - SHR Vx {, Vy}
                        0x06 => {
                            self.registers[0x0F] = self.registers[x] & 0x01;
                            self.registers[x] /= 2;
                        },
                        // 8xy7 - SUBN Vx, Vy
                        0x07 => {
                            self.registers[0x0F] = if (self.registers[y] > self.registers[x]) 1 else 0;
                            self.registers[x] = @subWithOverflow(self.registers[y], self.registers[x])[0];
                        },
                        // 8xyE - SHL Vx {, Vy}
                        0x0E => {
                            self.registers[0x0F] = self.registers[x] & 0x80;
                            self.registers[x] = @mulWithOverflow(self.registers[x], 2)[0];
                        },
                        else => unreachable,
                    }
                },
                // 9xy0 - SNE Vx, Vy
                0x9000 => {
                    if (self.registers[x] != self.registers[y]) self.program_counter += 2;
                },
                // Annn - LD. Set I = nnn.
                0xA000 => self.index_register = nnn,
                // Bnnn - JP V0, addr
                0xB000 => self.program_counter = nnn + self.registers[0],
                // Cxkk - RND Vx, byte
                0xC000 => self.registers[x] = nn & self.random.intRangeAtMost(u8, 0, 255),
                // DXYN - Display n-byte sprite at memory location I at (Vx, Vy), set VF = collision.
                0xD000 => {
                    const x_pos: u8 = self.registers[x] % DISPLAY_WIDTH;
                    const y_pos: u8 = self.registers[y] % DISPLAY_HEIGHT;

                    self.registers[0xF] = 0; // clear the collision flag

                    for (0..n) |row| {
                        const sprite_byte = self.memory[self.index_register + row];

                        for (0..8) |col| {
                            const sprite_pixel: u8 = sprite_byte & std.math.shr(u8, 0x80, col);

                            var loc = (y_pos + row) * DISPLAY_WIDTH + (x_pos + col);
                            if (loc < (DISPLAY_WIDTH * DISPLAY_HEIGHT)) {
                                const screen_pixel: *u32 = &self.video[(y_pos + row) * DISPLAY_WIDTH + (x_pos + col)];

                                if (sprite_pixel != 0) {
                                    if (screen_pixel.* == 0xFFFFFFFF) {
                                        self.registers[0xF] = 1;
                                    }

                                    screen_pixel.* ^= 0xFFFFFFFF;
                                }
                            }
                        }
                    }
                },
                0xE000 => {
                    switch (nn) {
                        // Ex9E - SKP Vx
                        0x9E => {
                            if (self.event.getScancodePressed(self.registers[x])) self.program_counter += 2;
                        },
                        // ExA1 - SKNP Vx
                        0xA1 => {
                            if (!self.event.getScancodePressed(self.registers[x])) self.program_counter += 2;
                        },
                        else => unreachable,
                    }
                },
                0xF000 => {
                    switch (nn) {
                        // Fx07 - LD Vx, DT
                        0x07 => self.registers[x] = self.delay_timer,
                        // Fx0A - LD Vx, K
                        0x0A => {
                            // retrieve the next keypress and store it in VX
                            var keys: [16]bool = undefined;
                            if (engine.Event.waitKey(&keys)) {
                                std.os.exit(9);
                            }

                            for (keys, 0..) |key_pressed, index| {
                                if (key_pressed) {
                                    self.registers[x] = @intCast(u8, index);
                                    break;
                                }
                            }
                        },
                        // Fx15 - LD DT, Vx
                        0x15 => self.delay_timer = self.registers[x],
                        // Fx18 - LD ST, Vx
                        0x18 => self.sound_timer = self.registers[x],
                        // Fx1E - ADD I, Vx
                        0x1E => self.index_register += self.registers[x],
                        // Fx29 - LD F, Vx
                        0x29 => self.index_register = self.registers[x] * 0x05,
                        // Fx33 - LD B, Vx
                        0x33 => {
                            var reg_data = self.registers[x];

                            self.memory[self.index_register + 2] = reg_data % 10;
                            reg_data /= 10;

                            self.memory[self.index_register + 1] = reg_data % 10;
                            reg_data /= 10;

                            self.memory[self.index_register] = reg_data;
                        },
                        // Fx55 - LD [I], Vx
                        0x55 => {
                            for (0..x + 1) |i| {
                                self.memory[self.index_register + i] = self.registers[i];
                            }
                        },
                        // Fx65 - LD Vx, [I]
                        0x65 => {
                            for (0..x + 1) |i| {
                                self.registers[i] = self.memory[self.index_register + i];
                            }
                        },
                        else => unreachable,
                    }
                },
                else => unreachable,
            }
        }
    }
};
