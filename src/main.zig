const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const math = @import("math.zig");
const render = @import("render.zig");
const mesh = @import("mesh.zig");
const obj = @import("obj.zig");
const Camera = @import("camera.zig").Camera;
const Mat4 = math.Mat4;

const windowWidth = 800;
const windowHeight = 600;

// escena de prueba de la fase 4 (generada con asistencia de IA)
const Fit = struct {
    center: rl.Vector3,
    scale: f32,
};

fn fitToSize(positions: []const rl.Vector3, size: f32) Fit {
    var lo = positions[0];
    var hi = positions[0];
    for (positions) |p| {
        lo = lo.min(p);
        hi = hi.max(p);
    }
    const extent = hi.subtract(lo);
    const largest = @max(extent.x, extent.y, extent.z);
    return .{
        .center = lo.add(extent.scale(0.5)),
        .scale = size / largest,
    };
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    rl.initWindow(windowWidth, windowHeight, "Space Travel");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var fb = try Framebuffer.init(gpa, windowWidth, windowHeight);
    defer fb.deinit(gpa);

    var sphere_low = try mesh.generateSphere(gpa, 8, 16);
    defer sphere_low.deinit(gpa);
    var sphere_mid = try mesh.generateSphere(gpa, 16, 32);
    defer sphere_mid.deinit(gpa);
    var sphere_high = try mesh.generateSphere(gpa, 32, 64);
    defer sphere_high.deinit(gpa);

    var model_obj = try obj.loadObj(gpa, io, "assets/models/model.obj");
    defer model_obj.deinit(gpa);
    const obj_fit = fitToSize(model_obj.positions, 4.0);

    const spheres = [_]render.Mesh{ sphere_low, sphere_mid, sphere_high };
    const sphere_x = [_]f32{ -9, -5, -1 };

    const aspect = @as(f32, windowWidth) / @as(f32, windowHeight);

    var camera = Camera{
        .position = .{ .x = 0, .y = 2, .z = 14 },
        .pitch = -0.1,
    };
    camera.captureMouse(true);

    var angle: f32 = 0;
    var title_buf: [192]u8 = undefined;

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        angle += dt * 0.5;
        camera.update(dt);

        const view_proj = Mat4.mul(camera.projection(aspect), camera.view());
        const spin = Mat4.rotateY(angle);

        fb.clear(rl.Color.black);

        var stats = render.Stats{};

        for (spheres, sphere_x) |sphere, x| {
            const model = Mat4.mul(
                Mat4.translate(.{ .x = x, .y = 0, .z = 0 }),
                Mat4.mul(spin, Mat4.scale(.{ .x = 1.5, .y = 1.5, .z = 1.5 })),
            );
            render.drawMesh(&fb, sphere, Mat4.mul(view_proj, model), &stats);
        }

        const s = obj_fit.scale;
        const obj_model = Mat4.mul(
            Mat4.translate(.{ .x = 6, .y = 0, .z = 0 }),
            Mat4.mul(
                spin,
                Mat4.mul(
                    Mat4.scale(.{ .x = s, .y = s, .z = s }),
                    Mat4.translate(obj_fit.center.negate()),
                ),
            ),
        );
        render.drawMesh(&fb, model_obj, Mat4.mul(view_proj, obj_model), &stats);

        fb.present();

        const p = camera.position;
        const title = std.fmt.bufPrintZ(
            &title_buf,
            "Space Travel - {d} FPS - drawn: {d} culled: {d} - obj tris: {d} - pos: ({d:.1}, {d:.1}, {d:.1})",
            .{ rl.getFPS(), stats.drawn, stats.culled, model_obj.indices.len, p.x, p.y, p.z },
        ) catch "Space Travel";
        rl.setWindowTitle(title);
    }
}
