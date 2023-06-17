const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});
const chip8 = @import("chip8.zig");
const engine = @import("engine.zig");
const cmd = @import("cmd_args.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.testing.expect(false) catch @panic("GeneralPurposeAllocator deinit failed");
    }

    // Setup Command Line Arguments
    var scaling_arg = cmd.Arg.ArgNode{
        .next = null,
        .name = "scaling",
        .arg_prefix = "-s ",
        .help = "Set screen scaling.",
        .required = false,
        .default = "8",
        .default_type = .INT,
        // .valid_values = .{ "2", "4", "8" },
    };
    var rom_arg = cmd.Arg.ArgNode{
        .next = &scaling_arg,
        .name = "rom",
        .arg_prefix = "-r ",
        .help = "Path to the ROM to load.",
        .required = true,
    };
    var cycle_speed_arg = cmd.Arg.ArgNode{
        .next = &rom_arg,
        .arg_prefix = "-c ",
        .name = "cycle",
        .help = "Set interpreter cycle speed.",
        .required = false,
        .default = "700",
        .default_type = .INT,
    };
    var cmd_args_list = cmd.Arg{
        .first = &cycle_speed_arg,
        .last = &scaling_arg,
    };
    try cmd.processCommandLineArgs(allocator, &cmd_args_list);
    defer cmd_args_list.deinit();
    const rom = rom_arg.value;
    const cycle = try std.fmt.parseInt(u16, cycle_speed_arg.value, 10);
    const scale = try std.fmt.parseInt(u16, scaling_arg.value, 10);

    const now = try std.time.Instant.now();
    var random_generator = std.rand.DefaultPrng.init(now.timestamp);
    const random = random_generator.random();

    var graphics = engine.Graphics.init("zCHIP8", chip8.DISPLAY_WIDTH * scale, chip8.DISPLAY_HEIGHT * scale, chip8.DISPLAY_WIDTH, chip8.DISPLAY_HEIGHT);
    defer graphics.free();

    engine.Event.init();

    // Start emulation
    var instance = chip8.Chip8.init(allocator, random);
    try instance.loadRom(rom, cycle);

    mainloop: while (true) {
        const quit = engine.Event.checkForQuit();
        if (quit) break :mainloop;

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
