const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const math = @import("math.zig");
const render = @import("render.zig");
const mesh = @import("mesh.zig");
const shaders = @import("shaders.zig");
const SolarSystem = @import("solar_system.zig").SolarSystem;
const Camera = @import("camera.zig").Camera;
const Mat4 = math.Mat4;

const windowWidth = 800;
const windowHeight = 600;

// escena del sistema solar (generada con asistencia de IA)
pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    rl.initWindow(windowWidth, windowHeight, "Space Travel");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var fb = try Framebuffer.init(gpa, windowWidth, windowHeight);
    defer fb.deinit(gpa);

    var sphere = try mesh.generateSphere(gpa, 32, 64);
    defer sphere.deinit(gpa);

    var system = try SolarSystem.init(gpa);
    defer system.deinit(gpa);

    var uniforms = shaders.Uniforms{
        .light_pos = system.sunPosition(),
        .light_color = .{ .x = 1, .y = 1, .z = 1 },
        .ambient = 0.06,
    };

    const aspect = @as(f32, windowWidth) / @as(f32, windowHeight);

    var camera = Camera{
        .position = .{ .x = 0, .y = 25, .z = 75 },
        .pitch = -0.3,
        .far = 500,
    };
    camera.captureMouse(true);

    var sim_time: f32 = 0;
    var time_scale: f32 = 1;
    var paused = false;
    var title_buf: [192]u8 = undefined;

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        camera.update(dt);

        // control del tiempo
        if (rl.isKeyPressed(.p)) paused = !paused;
        if (rl.isKeyPressed(.up)) time_scale = @min(time_scale * 2, 16);
        if (rl.isKeyPressed(.down)) time_scale = @max(time_scale / 2, 0.125);
        if (!paused) sim_time += dt * time_scale;

        uniforms.time += dt;
        system.update(sim_time);
        uniforms.light_pos = system.sunPosition();

        const view_proj = Mat4.mul(camera.projection(aspect), camera.view());

        fb.clear(rl.Color.black);

        var stats = render.Stats{};
        system.draw(&fb, sphere, view_proj, &uniforms, &stats);

        fb.present();

        const p = camera.position;
        const title = std.fmt.bufPrintZ(
            &title_buf,
            "Space Travel - {d} FPS - drawn: {d} - tiempo x{d}{s} - pos: ({d:.1}, {d:.1}, {d:.1})",
            .{ rl.getFPS(), stats.drawn, time_scale, @as([]const u8, if (paused) " (pausa)" else ""), p.x, p.y, p.z },
        ) catch "Space Travel";
        rl.setWindowTitle(title);
    }
}
