const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

pub const Graphics = struct {
    // const Self = @This();

    window: ?*c.SDL_Window,
    surface: [*c]c.SDL_Surface,
    texture: ?*c.SDL_Texture,
    renderer: ?*c.SDL_Renderer,
    video_pitch: c_int,

    pub fn init(title: [*c]const u8, width: c_int, height: c_int, buffer_width: c_int, buffer_height: c_int) Graphics {
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

    pub fn update(self: Graphics, buffer: ?*const anyopaque) void {
        _ = c.SDL_UpdateTexture(self.texture, null, buffer, self.video_pitch);
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderCopy(self.renderer, self.texture, null, null);
        c.SDL_RenderPresent(self.renderer);
    }

    pub fn free(self: Graphics) void {
        c.SDL_Quit();
        c.SDL_DestroyWindow(self.window);
        c.SDL_FreeSurface(self.surface);
        c.SDL_DestroyTexture(self.texture);
    }
};

pub const Event = struct {
    const Self = @This();

    pub fn init() void {
        if (c.SDL_Init(c.SDL_INIT_EVENTS) != 0) {
            std.debug.print("SDL failed to initialize: {s}\n", .{c.SDL_GetError()});
            std.os.exit(0);
        }
    }

    // TODO: Rename to something else
    pub fn waitKey(keys: *[16]bool) bool {
        var event: c.SDL_Event = undefined;
        var quit = false;

        while (c.SDL_PollEvent(&event) == 1) {
            switch (event.type) {
                c.SDL_QUIT => quit = true,
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_ESCAPE => quit = true,
                        c.SDLK_1 => keys[0x01] = true,
                        c.SDLK_2 => keys[0x02] = true,
                        c.SDLK_3 => keys[0x03] = true,
                        c.SDLK_4 => keys[0x0C] = true,
                        c.SDLK_q => keys[0x04] = true,
                        c.SDLK_w => keys[0x05] = true,
                        c.SDLK_e => keys[0x06] = true,
                        c.SDLK_r => keys[0x0D] = true,
                        c.SDLK_a => keys[0x07] = true,
                        c.SDLK_s => keys[0x08] = true,
                        c.SDLK_d => keys[0x09] = true,
                        c.SDLK_f => keys[0x0E] = true,
                        c.SDLK_z => keys[0x0A] = true,
                        c.SDLK_x => keys[0x00] = true,
                        c.SDLK_c => keys[0x0B] = true,
                        c.SDLK_v => keys[0x0F] = true,
                        else => {},
                    }
                },
                c.SDL_KEYUP => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_1 => keys[0x01] = false,
                        c.SDLK_2 => keys[0x02] = false,
                        c.SDLK_3 => keys[0x03] = false,
                        c.SDLK_4 => keys[0x0C] = false,
                        c.SDLK_q => keys[0x04] = false,
                        c.SDLK_w => keys[0x05] = false,
                        c.SDLK_e => keys[0x06] = false,
                        c.SDLK_r => keys[0x0D] = false,
                        c.SDLK_a => keys[0x07] = false,
                        c.SDLK_s => keys[0x08] = false,
                        c.SDLK_d => keys[0x09] = false,
                        c.SDLK_f => keys[0x0E] = false,
                        c.SDLK_z => keys[0x0A] = false,
                        c.SDLK_x => keys[0x00] = false,
                        c.SDLK_c => keys[0x0B] = false,
                        c.SDLK_v => keys[0x0F] = false,
                        else => {},
                    }
                },
                else => {},
            }
        }

        return quit;
    }
};
