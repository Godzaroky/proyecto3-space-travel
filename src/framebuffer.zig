const rl = @import("raylib");
const std = @import("std");

pub const Framebuffer = struct {
    width: i32,
    height: i32,
    color: []rl.Color,
    depth: []f32,
    texture: rl.Texture2D,

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32) !Framebuffer {
        const size: usize = @intCast(width * height);

        const color = try allocator.alloc(rl.Color, size);
        errdefer allocator.free(color);

        const depth = try allocator.alloc(f32, size);
        errdefer allocator.free(depth);

        const image = rl.genImageColor(width, height, rl.Color.black);
        defer rl.unloadImage(image);
        const texture = try rl.loadTextureFromImage(image);

        return .{
            .width = width,
            .height = height,
            .color = color,
            .depth = depth,
            .texture = texture,
        };
    }

    pub fn deinit(self: *Framebuffer, allocator: std.mem.Allocator) void {
        rl.unloadTexture(self.texture);
        allocator.free(self.color);
        allocator.free(self.depth);
    }

    pub fn clear(self: *Framebuffer, c: rl.Color) void {
        @memset(self.color, c);
        @memset(self.depth, std.math.inf(f32));
    }

    pub fn setPixel(self: *Framebuffer, x: i32, y: i32, c: rl.Color) void {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) return;
        const i: usize = @intCast(y * self.width + x);
        self.color[i] = c;
    }

    pub fn setPixelDepth(self: *Framebuffer, x: i32, y: i32, z: f32, c: rl.Color) void {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) return;
        const i: usize = @intCast(y * self.width + x);
        if (z < self.depth[i]) {
            self.depth[i] = z;
            self.color[i] = c;
        }
    }

    pub fn drawLine(self: *Framebuffer, x0: i32, y0: i32, x1: i32, y1: i32, c: rl.Color) void {
        const dx: i32 = if (x1 > x0) x1 - x0 else x0 - x1;
        const dy: i32 = -(if (y1 > y0) y1 - y0 else y0 - y1);
        const sx: i32 = if (x0 < x1) 1 else -1;
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err = dx + dy;
        var x = x0;
        var y = y0;

        while (true) {
            self.setPixel(x, y, c);
            if (x == x1 and y == y1) break;
            const e2 = err * 2;
            if (e2 >= dy) {
                err += dy;
                x += sx;
            }
            if (e2 <= dx) {
                err += dx;
                y += sy;
            }
        }
    }

    pub fn present(self: *Framebuffer) void {
        rl.updateTexture(self.texture, self.color.ptr);
        rl.beginDrawing();
        rl.drawTexture(self.texture, 0, 0, rl.Color.white);
        rl.endDrawing();
    }
};
