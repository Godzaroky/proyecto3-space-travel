const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const math = @import("math.zig");
const render = @import("render.zig");
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

const cube_indices = [12][3]u32{
    .{ 4, 5, 6 }, .{ 4, 6, 7 }, // +Z
    .{ 1, 0, 3 }, .{ 1, 3, 2 }, // -Z
    .{ 5, 1, 2 }, .{ 5, 2, 6 }, // +X
    .{ 0, 4, 7 }, .{ 0, 7, 3 }, // -X
    .{ 7, 6, 2 }, .{ 7, 2, 3 }, // +Y
    .{ 0, 1, 5 }, .{ 0, 5, 4 }, // -Y
};

// cubo RGB
const cube_colors = [8]rl.Vector3{
    .{ .x = 1, .y = 0, .z = 0 },
    .{ .x = 0, .y = 1, .z = 0 },
    .{ .x = 0, .y = 0, .z = 1 },
    .{ .x = 1, .y = 1, .z = 0 },
    .{ .x = 1, .y = 0, .z = 1 },
    .{ .x = 0, .y = 1, .z = 1 },
    .{ .x = 1, .y = 1, .z = 1 },
    .{ .x = 0.5, .y = 0.5, .z = 0.5 },
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

    const cube = render.Mesh{
        .positions = &cube_vertices,
        .colors = &cube_colors,
        .indices = &cube_indices,
    };

    const aspect = @as(f32, windowWidth) / @as(f32, windowHeight);
    const proj = Mat4.perspective(std.math.degreesToRadians(60.0), aspect, 0.1, 100.0);
    const view = Mat4.lookAt(
        .{ .x = 0, .y = 0, .z = 5 },
        .{ .x = 0, .y = 0, .z = 0 },
        .{ .x = 0, .y = 1, .z = 0 },
    );

    var angle: f32 = 0;
    var title_buf: [128]u8 = undefined;

    while (!rl.windowShouldClose()) {
        angle += rl.getFrameTime();
        const model = Mat4.mul(Mat4.rotateY(angle), Mat4.rotateX(angle * 0.5));
        const mvp = Mat4.mul(proj, Mat4.mul(view, model));

        fb.clear(rl.Color.black);

        var stats = render.Stats{};
        render.drawMesh(&fb, cube, mvp, &stats);

        fb.present();

        const title = std.fmt.bufPrintZ(
            &title_buf,
            "Space Travel - {d} FPS - drawn: {d} culled: {d}",
            .{ rl.getFPS(), stats.drawn, stats.culled },
        ) catch "Space Travel";
        rl.setWindowTitle(title);
    }
}
