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

    const VIDEO_SCALE = 8;
    var window = c.SDL_CreateWindow("CHIP8", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, chip8.DISPLAY_WIDTH * VIDEO_SCALE, chip8.DISPLAY_HEIGHT * VIDEO_SCALE, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_SOFTWARE);
    defer c.SDL_DestroyRenderer(renderer);

    // Setup SDL Texture and Surface
    // const surface = c.SDL_CreateRGBSurface(0, chip8.DISPLAY_WIDTH, chip8.DISPLAY_HEIGHT, 32, 0, 0, 0, 0);
    // defer c.SDL_FreeSurface(surface);
    // const video_pitch = @typeInfo(instance.video[0]).Int.bits * chip8.DISPLAY_HEIGHT; //@as(c_int, surface.*.pitch * surface.*.h);

    const surface = c.SDL_CreateRGBSurface(0, chip8.DISPLAY_WIDTH * VIDEO_SCALE, chip8.DISPLAY_HEIGHT * VIDEO_SCALE, 32, 0, 0, 0, 0);
    defer c.SDL_FreeSurface(surface);

    // const texture = c.SDL_CreateTextureFromSurface(renderer, surface);
    // defer c.SDL_DestroyTexture(texture);

    // Start emulation
    var instance = chip8.Chip8.init(allocator, random);
    try instance.loadRom("IBM Logo.ch8");
    const video_pitch = @sizeOf(u32) * chip8.DISPLAY_HEIGHT;
    _ = video_pitch;

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

        // const video_memory: ?*const anyopaque = @ptrCast(?*anyopaque, &instance.video);
        // _ = c.memcpy(surface.*.pixels, &instance.video[0], video_pitch);
        const num: usize = @intCast(usize, surface.*.pitch * surface.*.h);
        const video_memory = @ptrCast(?*anyopaque, &instance.video);
        _ = c.memcpy(surface.*.pixels, video_memory, num);
        // _ = c.memcpy(surface.*.pixels, &instance.video[0], video_pitch);
        const texture = c.SDL_CreateTextureFromSurface(renderer, surface);
        // _ = c.SDL_UpdateTexture(texture, null, ptr, video_pitch);
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
