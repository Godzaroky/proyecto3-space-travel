const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const math = @import("math.zig");
const render = @import("render.zig");
const Camera = @import("camera.zig").Camera;
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

// escena de prueba: cuadrícula de cubos (generada con asistencia de IA)
const grid_half = 3;
const grid_spacing = 6.0;

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

    var camera = Camera{
        .position = .{ .x = 0, .y = 4, .z = 25 },
        .pitch = -0.15,
    };
    camera.captureMouse(true);

    var angle: f32 = 0;
    var title_buf: [160]u8 = undefined;

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        angle += dt;
        camera.update(dt);

        const view_proj = Mat4.mul(camera.projection(aspect), camera.view());

        fb.clear(rl.Color.black);

        var stats = render.Stats{};
        const spin = Mat4.mul(Mat4.rotateY(angle), Mat4.rotateX(angle * 0.5));

        var gz: i32 = -grid_half;
        while (gz <= grid_half) : (gz += 1) {
            var gx: i32 = -grid_half;
            while (gx <= grid_half) : (gx += 1) {
                const offset = rl.Vector3{
                    .x = @as(f32, @floatFromInt(gx)) * grid_spacing,
                    .y = 0,
                    .z = @as(f32, @floatFromInt(gz)) * grid_spacing,
                };
                const model = Mat4.mul(Mat4.translate(offset), spin);
                render.drawMesh(&fb, cube, Mat4.mul(view_proj, model), &stats);
            }
        }

        fb.present();

        const p = camera.position;
        const title = std.fmt.bufPrintZ(
            &title_buf,
            "Space Travel - {d} FPS - drawn: {d} culled: {d} - pos: ({d:.1}, {d:.1}, {d:.1})",
            .{ rl.getFPS(), stats.drawn, stats.culled, p.x, p.y, p.z },
        ) catch "Space Travel";
        rl.setWindowTitle(title);
    }
}
