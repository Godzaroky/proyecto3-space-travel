const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const math = @import("math.zig");
const Mat4 = math.Mat4;

const windowWidth = 800;
const windowHeight = 600;

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

// cubo de prueba
const cube_vertices = [8]rl.Vector3{
    .{ .x = -1, .y = -1, .z = -1 },
    .{ .x = 1, .y = -1, .z = -1 },
    .{ .x = 1, .y = 1, .z = -1 },
    .{ .x = -1, .y = 1, .z = -1 },
    .{ .x = -1, .y = -1, .z = 1 },
    .{ .x = 1, .y = -1, .z = 1 },
    .{ .x = 1, .y = 1, .z = 1 },
    .{ .x = -1, .y = 1, .z = 1 },
};

const cube_edges = [12][2]usize{
    .{ 0, 1 }, .{ 1, 2 }, .{ 2, 3 }, .{ 3, 0 },
    .{ 4, 5 }, .{ 5, 6 }, .{ 6, 7 }, .{ 7, 4 },
    .{ 0, 4 }, .{ 1, 5 }, .{ 2, 6 }, .{ 3, 7 },
};

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

    var fb = try Framebuffer.init(gpa, windowWidth, windowHeight);
    defer fb.deinit(gpa);

    const aspect = @as(f32, windowWidth) / @as(f32, windowHeight);
    const proj = Mat4.perspective(std.math.degreesToRadians(60.0), aspect, 0.1, 100.0);
    const view = Mat4.lookAt(
        .{ .x = 0, .y = 0, .z = 5 },
        .{ .x = 0, .y = 0, .z = 0 },
        .{ .x = 0, .y = 1, .z = 0 },
    );

    var angle: f32 = 0;
    var title_buf: [64]u8 = undefined;

    while (!rl.windowShouldClose()) {
        angle += rl.getFrameTime();
        const model = math.Mat4.mul(math.Mat4.rotateY(angle), math.Mat4.rotateX(angle * 0.5));
        const mvp = math.Mat4.mul(proj, math.Mat4.mul(view, model));

        fb.clear(rl.Color.black);

        var screen: [8]rl.Vector3 = undefined;
        var visible: [8]bool = undefined;
        for (cube_vertices, 0..) |v, i| {
            const clip = math.Mat4.mulVec4(mvp, .{ .x = v.x, .y = v.y, .z = v.z, .w = 1 });
            visible[i] = clip.w > 0;
            if (visible[i]) {
                screen[i] = math.Mat4.toScreen(clip, windowWidth, windowHeight);
            }
        }

        for (cube_edges) |edge| {
            const a = edge[0];
            const b = edge[1];
            if (!visible[a] or !visible[b]) continue;
            fb.drawLine(
                @intFromFloat(screen[a].x),
                @intFromFloat(screen[a].y),
                @intFromFloat(screen[b].x),
                @intFromFloat(screen[b].y),
                rl.Color.white,
            );
        }

        fb.present();

        const title = std.fmt.bufPrintZ(&title_buf, "Space Travel - {d} FPS", .{rl.getFPS()}) catch "Space Travel";
        rl.setWindowTitle(title);
    }
}
