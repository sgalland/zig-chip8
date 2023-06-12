const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});
const chip8 = @import("chip8.zig");
const engine = @import("engine.zig");
const cmd = @import("cmd_args.zig");

pub fn findDefaultRoms() ![]const u8 {
    const known_working_roms = [_][]const u8{ "IBM Logo.ch8", "test_opcode.ch8" };

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd_path = try std.os.getcwd(&buf);

    var directory = try std.fs.cwd().openIterableDir(cwd_path, .{});
    defer directory.close();

    var iterator = directory.iterate();
    while (try iterator.next()) |file| {
        if (file.kind != .file) continue;

        for (known_working_roms) |rom| {
            if (std.mem.endsWith(u8, file.name, ".ch8") and std.mem.eql(u8, file.name, rom))
                return file.name;
        }
    }

    return undefined;
}

pub fn main() !void {
    // Make user configurable
    const VIDEO_SCALE = 8;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.testing.expect(false) catch @panic("GeneralPurposeAllocator deinit failed");
    }

    var rom: [:0]const u8 = "IBM Logo.ch8";

    var myArgList = cmd.Arg{
        .first = null,
        .last = null,
    };

    var scaling_arg = cmd.Arg.ArgNode{
        .next = null,
        .arg_prefix = "-s=",
        .help = "Set screen scaling. {2,4,8}",
        .required = true,
        .default = "8",
        .default_type = .INT,
    };
    var rom_arg = cmd.Arg.ArgNode{
        .next = &scaling_arg,
        .arg_prefix = "-r=",
        .help = "Path to the ROM to load.",
        .required = true,
    };
    var cycle_speed_arg = cmd.Arg.ArgNode{
        .next = &rom_arg,
        .arg_prefix = "-c=",
        .help = "Set interpreter cycle speed.",
        .required = false,
        .default = "700",
        .default_type = .INT,
    };
    myArgList.first = &cycle_speed_arg;
    try cmd.createCmdLineArgs(allocator, myArgList);

    const now = try std.time.Instant.now();
    var random_generator = std.rand.DefaultPrng.init(now.timestamp);
    const random = random_generator.random();

    var graphics = engine.Graphics.init("zCHIP8", chip8.DISPLAY_WIDTH * VIDEO_SCALE, chip8.DISPLAY_HEIGHT * VIDEO_SCALE, chip8.DISPLAY_WIDTH, chip8.DISPLAY_HEIGHT);
    defer graphics.free();

    var events = [_]engine.EventType{.{ .@"0" = c.SDL_QUIT, .@"1" = false }};
    var event_e = engine.Event.init(&events);

    // Start emulation
    var instance = chip8.Chip8.init(allocator, random, &event_e);
    try instance.loadRom(rom);

    mainloop: while (true) {
        // Process events
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }

        if (event_e.getKeyPressed(c.SDL_SCANCODE_ESCAPE)) break :mainloop;

        instance.cycle(@intCast(u64, std.time.milliTimestamp()));

        graphics.update(&instance.video);
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
