const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});
const chip8 = @import("chip8.zig");

pub fn main() !void {
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

    var window = c.SDL_CreateWindow("CHIP8", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, chip8.DISPLAY_WIDTH, chip8.DISPLAY_HEIGHT, 0);
    defer c.SDL_DestroyWindow(window);

    // This should enable scaling
    _ = c.SDL_SetWindowSize(window, 640, 480);
    var renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_SOFTWARE);
    defer c.SDL_DestroyRenderer(renderer);
    _ = c.SDL_RenderSetScale(renderer, 4, 4);
    _ = c.SDL_RenderSetLogicalSize(renderer, 640, 480);

    // Setup SDL Texture and Surface
    const surface = c.SDL_CreateRGBSurface(0, chip8.DISPLAY_WIDTH, chip8.DISPLAY_HEIGHT, 32, 0, 0, 0, 0);
    defer c.SDL_FreeSurface(surface);

    // Start emulation
    var instance = chip8.Chip8.init(allocator, random);
    try instance.loadRom("IBM Logo.ch8");

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

        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_SetRenderTarget(renderer, null);
        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0x00);

        const num: usize = @intCast(usize, surface.*.pitch * surface.*.h);
        const video_memory = @ptrCast(?*anyopaque, &instance.video);
        _ = c.memcpy(surface.*.pixels, video_memory, num);

        const texture = c.SDL_CreateTextureFromSurface(renderer, surface);

        const destRect: c.SDL_Rect = c.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = chip8.DISPLAY_WIDTH,
            .h = chip8.DISPLAY_HEIGHT,
        };
        _ = c.SDL_RenderCopy(renderer, texture, null, &destRect);
        c.SDL_RenderPresent(renderer);
        c.SDL_DestroyTexture(texture);
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
