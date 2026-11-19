const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const math = @import("math.zig");
const render = @import("render.zig");
const mesh = @import("mesh.zig");
const shaders = @import("shaders.zig");
const SolarSystem = @import("solar_system.zig").SolarSystem;
const Camera = @import("camera.zig").Camera;
const Skybox = @import("skybox.zig").Skybox;
const Ship = @import("ship.zig").Ship;
const Mat4 = math.Mat4;

const windowWidth = 800;
const windowHeight = 600;

// resoluciones de la esfera para cada nivel de LOD
const lod_resolutions = [_][2]u32{
    .{ 8, 16 },
    .{ 16, 32 },
    .{ 32, 64 },
    .{ 64, 128 },
};

// escena del sistema solar (generada con asistencia de IA)
pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    rl.initWindow(windowWidth, windowHeight, "Space Travel");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var fb = try Framebuffer.init(gpa, windowWidth, windowHeight);
    defer fb.deinit(gpa);

    var lods: [lod_resolutions.len]render.Mesh = undefined;
    var lod_count: usize = 0;
    defer for (lods[0..lod_count]) |*m| m.deinit(gpa);
    for (lod_resolutions, 0..) |res, i| {
        lods[i] = try mesh.generateSphere(gpa, res[0], res[1]);
        lod_count += 1;
    }

    var ring = try mesh.generateRing(gpa, 1.3, 2.4, 96);
    defer ring.deinit(gpa);

    var system = try SolarSystem.init(gpa);
    defer system.deinit(gpa);

    var skybox = try Skybox.init(gpa, 1024);
    defer skybox.deinit(gpa);

    var renderer = render.Renderer.init(gpa);
    defer renderer.deinit();

    var ship = try Ship.init(gpa, io, "assets/models/ship.obj");
    defer ship.deinit(gpa);

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
    var title_buf: [256]u8 = undefined;

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        camera.update(dt);
        ship.update(dt);

        // control del tiempo
        if (rl.isKeyPressed(.p)) paused = !paused;
        if (rl.isKeyPressed(.up)) time_scale = @min(time_scale * 2, 16);
        if (rl.isKeyPressed(.down)) time_scale = @max(time_scale / 2, 0.125);
        if (!paused) sim_time += dt * time_scale;

        uniforms.time += dt;
        system.update(sim_time);
        uniforms.light_pos = system.sunPosition();
        uniforms.camera_pos = camera.position;

        const view_proj = Mat4.mul(camera.projection(aspect), camera.view());

        fb.clear(rl.Color.black);

        renderer.begin();
        try system.drawOpaque(&renderer, &fb, &lods, &camera, aspect, view_proj, &uniforms);
        try ship.draw(&renderer, &fb, camera, view_proj, &uniforms);
        try system.drawTransparent(&renderer, &fb, ring, &camera, aspect, view_proj, &uniforms);
        renderer.flush(&fb, &uniforms, .{ .skybox = &skybox, .camera = &camera, .aspect = aspect });

        fb.present();

        const s = renderer.stats;
        const title = std.fmt.bufPrintZ(
            &title_buf,
            "Space Travel - {d} FPS - hilos: {d} - tris: {d} - LOD: {d}/{d}/{d}/{d} - fuera de vista: {d} - tiempo x{d}{s}",
            .{
                rl.getFPS(),
                renderer.thread_count,
                s.drawn,
                s.lod[0],
                s.lod[1],
                s.lod[2],
                s.lod[3],
                s.bodies_culled,
                time_scale,
                @as([]const u8, if (paused) " (pausa)" else ""),
            },
        ) catch "Space Travel";
        rl.setWindowTitle(title);
    }
}
