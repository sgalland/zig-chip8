const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

pub const Graphics = struct {
    const Self = @This();

    window: ?*c.SDL_Window,
    surface: [*c]c.SDL_Surface,
    texture: ?*c.SDL_Texture,
    renderer: ?*c.SDL_Renderer,
    video_pitch: c_int,

    pub fn init(title: [*c]const u8, width: c_int, height: c_int, buffer_width: c_int, buffer_height: c_int) Self {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
            std.debug.print("SDL failed to initialize: {s}\n", .{c.SDL_GetError()});
            std.os.exit(0);
        }

        var graphics = Graphics{
            .window = undefined,
            .surface = undefined,
            .texture = undefined,
            .renderer = undefined,
            .video_pitch = @sizeOf(c_int) * buffer_width,
        };

        graphics.window = c.SDL_CreateWindow(title, c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, width, height, c.SDL_WINDOW_SHOWN);
        graphics.renderer = c.SDL_CreateRenderer(graphics.window, -1, c.SDL_RENDERER_ACCELERATED);
        graphics.surface = c.SDL_CreateRGBSurface(0, buffer_width, buffer_height, 32, 0, 0, 0, 0);
        graphics.texture = c.SDL_CreateTexture(graphics.renderer, graphics.surface.*.format.*.format, c.SDL_TEXTUREACCESS_STREAMING, graphics.surface.*.w, graphics.surface.*.h);

        return graphics;
    }

    pub fn update(self: *Self, buffer: ?*const anyopaque) void {
        _ = c.SDL_UpdateTexture(self.texture, null, buffer, self.video_pitch);
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderCopy(self.renderer, self.texture, null, null);
        c.SDL_RenderPresent(self.renderer);
    }

    pub fn free(self: *Self) void {
        c.SDL_Quit();
        c.SDL_DestroyWindow(self.window);
        c.SDL_FreeSurface(self.surface);
        c.SDL_DestroyTexture(self.texture);
    }
};

pub const EventType = std.meta.Tuple(&.{ u32, bool });

pub const Event = struct {
    const Self = @This();

    events: []EventType,

    pub fn init(events: []EventType) Self {
        if (c.SDL_Init(c.SDL_INIT_EVENTS) != 0) {
            std.debug.print("SDL failed to initialize: {s}\n", .{c.SDL_GetError()});
            std.os.exit(0);
        }

        return Event{ .events = events };
    }

    pub fn getKeyPressed(self: *Self, key_pressed: u32) bool {
        _ = self;

        c.SDL_PumpEvents();
        const key_state = c.SDL_GetKeyboardState(null);
        return key_state[key_pressed] > 0;
    }

    pub fn getScancodePressed(self: *Self, scancode: u32) bool {
        _ = self;

        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_KEYDOWN => {
                    if (event.key.keysym.scancode == scancode) return true;
                },
                else => {},
            }
        }

        return false;
    }

    pub fn  getCurrentKeyPress() void {
        
    }
};
