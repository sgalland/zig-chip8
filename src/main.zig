const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});
const chip8 = @import("chip8.zig");

pub fn main() !void {
    // Make user configurable
    const VIDEO_SCALE = 8;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.testing.expect(false) catch @panic("GeneralPurposeAllocator deinit failed");
    }

    var cmd_args = try std.process.argsWithAllocator(allocator);
    defer cmd_args.deinit();

    while (cmd_args.next()) |arg| {
        std.debug.print("Command line arg: {s}\n", .{arg});
    }

    const now = try std.time.Instant.now();
    var random_generator = std.rand.DefaultPrng.init(now.timestamp);
    const random = random_generator.random();

    // Start emulation
    var instance = chip8.Chip8.init(allocator, random);
    try instance.loadRom("IBM Logo.ch8");

    // Initialize SDL
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("zCHIP8", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, chip8.DISPLAY_WIDTH * VIDEO_SCALE, chip8.DISPLAY_HEIGHT * VIDEO_SCALE, c.SDL_WINDOW_SHOWN);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED);
    defer c.SDL_DestroyRenderer(renderer);

    const surface = c.SDL_CreateRGBSurface(0, chip8.DISPLAY_WIDTH, chip8.DISPLAY_HEIGHT, 32, 0, 0, 0, 0);
    defer c.SDL_FreeSurface(surface);

    _ = c.SDL_SetSurfaceRLE(surface, c.SDL_TRUE);

    const texture = c.SDL_CreateTexture(renderer, surface.*.format.*.format, c.SDL_TEXTUREACCESS_STREAMING, surface.*.w, surface.*.h);
    defer c.SDL_DestroyTexture(texture);

    //  The pitch size must be fron c_int, otherwise its just wrong
    const video_pitch = @sizeOf(u32) * chip8.DISPLAY_WIDTH;

    var step: usize = 0;
    _ = step;

    //
    //
    // TEST CODE
    //
    //
    const foo = try std.time.Instant.now();
    var prgn = std.rand.DefaultPrng.init(foo.timestamp);
    const rnd = prgn.random();
    _ = rnd;

    var text_buffer: [chip8.DISPLAY_WIDTH * chip8.DISPLAY_HEIGHT]u32 = [_]u32{0} ** (chip8.DISPLAY_WIDTH * chip8.DISPLAY_HEIGHT);
    for (0..chip8.DISPLAY_WIDTH) |x| {
        for (0..chip8.DISPLAY_HEIGHT) |y| {
            const pos = y * chip8.DISPLAY_WIDTH + x;

            // if (x == step and y == step) {
            //     text_buffer[pos] = rnd.intRangeAtMost(u32, 0xFF000000, 0xFFFFFFFF);
            //     //0xFFFFFFFF;
            //     step += 1;
            // } else text_buffer[pos] = 0x00000000;

            if (x == 0 or x == chip8.DISPLAY_WIDTH - 1 or y == 0 or y == chip8.DISPLAY_HEIGHT - 1) text_buffer[pos] = 0xFFFF0000;
        }
    }

    mainloop: while (true) {
        // Process events
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }

        const time_now = try std.time.Instant.now();
        instance.cycle(time_now.timestamp);

        // Need to draw the pixels
        // See: https://github.com/sgalland/SAGE-CPP/blob/master/src/backend/sdl2/Graphics.cpp

        _ = c.SDL_UpdateTexture(texture, null, &instance.video, video_pitch);
        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderCopy(renderer, texture, null, null);
        c.SDL_RenderPresent(renderer);
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
