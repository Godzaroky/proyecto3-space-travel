const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");

const windowWidth = 800;
const windowHeight = 600;

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    rl.initWindow(windowWidth, windowHeight, "Space Travel");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // framebuffer de colores
    const pixels = try gpa.alloc(rl.Color, windowWidth * windowHeight);
    defer gpa.free(pixels);

    const image = rl.genImageColor(windowWidth, windowHeight, rl.Color.black);
    const texture = try rl.loadTextureFromImage(image);
    rl.unloadImage(image);
    defer rl.unloadTexture(texture);

    while (!rl.windowShouldClose()) {
        // 1. Limpiar
        for (pixels) |*p| {
            p.* = rl.Color.black;
        }

        // 2. Dibujar
        for (0..windowHeight) |y| {
            for (0..windowWidth) |x| {
                const r: u8 = @intCast(x * 255 / windowWidth);
                const g: u8 = @intCast(y * 255 / windowHeight);
                setPixels(pixels, x, y, rl.Color.init(r, g, 128, 255));
            }
        }

        // 3. Presentar
        rl.updateTexture(texture, pixels.ptr);
        rl.beginDrawing();
        rl.drawTexture(texture, 0, 0, rl.Color.white);
        rl.drawFPS(10, 10);
        rl.endDrawing();
    }
}

pub fn setPixels(pixels: []rl.Color, x: usize, y: usize, color: rl.Color) void {
    if (x >= windowWidth or y >= windowHeight) {
        return;
    }
    pixels[y * windowWidth + x] = color;
}
