const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});
const chip8 = @import("chip8.zig");

pub fn main() !void {
    // Make user configurable
    const VIDEO_SCALE = 8;
    const VIDEO_WIDTH = 64;
    const VIDEO_HEIGHT = 32;

    const NEW_VIDEO_WIDTH = VIDEO_WIDTH * VIDEO_SCALE;
    const NEW_VIDEO_HEIGHT = VIDEO_HEIGHT * VIDEO_SCALE;

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

    // Initialize SDL
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("CHIP8", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, NEW_VIDEO_WIDTH, NEW_VIDEO_HEIGHT, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_SOFTWARE);
    defer c.SDL_DestroyRenderer(renderer);

    // This should enable scaling
    _ = c.SDL_SetWindowSize(window, NEW_VIDEO_WIDTH, NEW_VIDEO_HEIGHT);
    _ = c.SDL_RenderSetLogicalSize(renderer, NEW_VIDEO_WIDTH, NEW_VIDEO_HEIGHT);
    _ = c.SDL_RenderSetScale(renderer, VIDEO_SCALE, VIDEO_SCALE);

    // Setup SDL Texture and Surface
    const surface = c.SDL_CreateRGBSurface(0, chip8.DISPLAY_WIDTH, chip8.DISPLAY_HEIGHT, 32, 0, 0, 0, 0);
    defer c.SDL_FreeSurface(surface);

    // const video_pitch = @sizeOf(u32) * VIDEO_HEIGHT;
    //TODO: This pitch appears to get rid of duplication
    const video_pitch = @sizeOf(u32) * VIDEO_WIDTH;

    const texture = c.SDL_CreateTextureFromSurface(renderer, surface);
    defer c.SDL_DestroyTexture(texture);

    // Start emulation
    var instance = chip8.Chip8.init(allocator, random);
    try instance.loadRom("IBM Logo.ch8");

    var step: usize = 0;

    //
    //
    // TEST CODE
    //
    //
    const foo = try std.time.Instant.now();
    var prgn = std.rand.DefaultPrng.init(foo.timestamp);
    const rnd = prgn.random();
    var text_buffer: [VIDEO_WIDTH * VIDEO_HEIGHT]u32 = undefined;
    for (0..VIDEO_WIDTH) |x| {
        for (0..VIDEO_HEIGHT) |y| {
            // const pos = x * 64 + y;
            // if (y % 2 != 0)
            //     text_buffer[pos] = 0x00000000
            // else
            //     text_buffer[pos] = 0xFFFFFF;
            const pos = x * VIDEO_HEIGHT + y;
            if (x == step and y == step and x < VIDEO_WIDTH and y < VIDEO_HEIGHT) {
                text_buffer[pos] = rnd.intRangeAtMost(u32, 0x00000000, 0xFFFFFF);
                step += 1;
            } else {
                text_buffer[pos] = 0x00000000;
            }
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

        if (instance.update_display) {
            //instance.video
            _ = c.SDL_UpdateTexture(texture, null, &instance.video, @intCast(c_int, video_pitch));
            _ = c.SDL_RenderClear(renderer);
            _ = c.SDL_RenderCopy(renderer, texture, null, null);
            c.SDL_RenderPresent(renderer);
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
