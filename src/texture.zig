// Generado con asistencia de IA (Claude)
const rl = @import("raylib");
const std = @import("std");

pub const Texture = struct {
    width: i32,
    height: i32,
    pixels: []rl.Color,

    pub fn load(allocator: std.mem.Allocator, path: [:0]const u8) !Texture {
        const image = try rl.loadImage(path);
        defer rl.unloadImage(image);
        const colors = try rl.loadImageColors(image);
        defer rl.unloadImageColors(colors);

        const pixels = try allocator.alloc(rl.Color, colors.len);
        @memcpy(pixels, colors);

        return .{
            .width = @intCast(image.width),
            .height = @intCast(image.height),
            .pixels = pixels,
        };
    }

    // tablero para probar la corrección de perspectiva
    pub fn checker(allocator: std.mem.Allocator, size: i32, cells: i32, a: rl.Color, b: rl.Color) !Texture {
        const pixels = try allocator.alloc(rl.Color, @intCast(size * size));
        const cell_size = @divTrunc(size, cells);

        var y: i32 = 0;
        while (y < size) : (y += 1) {
            var x: i32 = 0;
            while (x < size) : (x += 1) {
                const odd = @mod(@divTrunc(x, cell_size) + @divTrunc(y, cell_size), 2);
                const i: usize = @intCast(y * size + x);
                pixels[i] = if (odd == 0) a else b;
            }
        }

        return .{
            .width = size,
            .height = size,
            .pixels = pixels,
        };
    }

    // textura de 1x1 de un solo color
    pub fn solid(allocator: std.mem.Allocator, color: rl.Color) !Texture {
        const pixels = try allocator.alloc(rl.Color, 1);
        pixels[0] = color;
        return .{
            .width = 1,
            .height = 1,
            .pixels = pixels,
        };
    }

    pub fn deinit(self: *Texture, allocator: std.mem.Allocator) void {
        allocator.free(self.pixels);
    }

    pub fn sample(self: *const Texture, u: f32, v: f32) rl.Color {
        const uu = u - @floor(u);
        const vv = std.math.clamp(v, 0, 1);
        const w: f32 = @floatFromInt(self.width);
        const h: f32 = @floatFromInt(self.height);
        const x: i32 = @min(@as(i32, @intFromFloat(uu * w)), self.width - 1);
        const y: i32 = @min(@as(i32, @intFromFloat(vv * h)), self.height - 1);
        const i: usize = @intCast(y * self.width + x);
        return self.pixels[i];
    }
};
