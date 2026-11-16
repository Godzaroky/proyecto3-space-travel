const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const math = @import("math.zig");
const render = @import("render.zig");
const mesh = @import("mesh.zig");
const shaders = @import("shaders.zig");
const Texture = @import("texture.zig").Texture;
const Camera = @import("camera.zig").Camera;
const Mat4 = math.Mat4;

const windowWidth = 800;
const windowHeight = 600;

fn uniformScale(s: f32) Mat4 {
    return Mat4.scale(.{ .x = s, .y = s, .z = s });
}

// escena de prueba de la fase 5 (generada con asistencia de IA)
pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    rl.initWindow(windowWidth, windowHeight, "Space Travel");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var fb = try Framebuffer.init(gpa, windowWidth, windowHeight);
    defer fb.deinit(gpa);

    var sphere = try mesh.generateSphere(gpa, 32, 64);
    defer sphere.deinit(gpa);

    var checker_tex = try Texture.checker(gpa, 256, 8, rl.Color.white, rl.Color.black);
    defer checker_tex.deinit(gpa);
    var sun_tex = try Texture.load(gpa, "assets/textures/sun.png");
    defer sun_tex.deinit(gpa);
    var earth_tex = try Texture.load(gpa, "assets/textures/earth.png");
    defer earth_tex.deinit(gpa);

    const checker_mat = shaders.Material{ .texture = &checker_tex, .shader = &shaders.emissive };
    const sun_mat = shaders.Material{ .texture = &sun_tex, .shader = &shaders.emissive };
    const earth_mat = shaders.Material{ .texture = &earth_tex, .shader = &shaders.litTextured };

    var uniforms = shaders.Uniforms{
        .light_pos = .{ .x = 0, .y = 0, .z = 0 },
        .light_color = .{ .x = 1, .y = 1, .z = 1 },
        .ambient = 0.08,
    };

    const aspect = @as(f32, windowWidth) / @as(f32, windowHeight);

    var camera = Camera{
        .position = .{ .x = 0, .y = 6, .z = 28 },
        .pitch = -0.2,
    };
    camera.captureMouse(true);

    var title_buf: [192]u8 = undefined;

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        uniforms.time += dt;
        const t = uniforms.time;
        camera.update(dt);

        const view_proj = Mat4.mul(camera.projection(aspect), camera.view());

        fb.clear(rl.Color.black);

        var stats = render.Stats{};

        // sol
        const sun_model = Mat4.mul(Mat4.rotateY(t * 0.1), uniformScale(3));
        render.drawMesh(&fb, sphere, sun_model, view_proj, &sun_mat, &uniforms, &stats);

        // planeta orbitando
        const orbit = t * 0.3;
        const earth_model = Mat4.mul(
            Mat4.translate(.{ .x = @cos(orbit) * 12, .y = 0, .z = @sin(orbit) * 12 }),
            Mat4.rotateY(t),
        );
        render.drawMesh(&fb, sphere, earth_model, view_proj, &earth_mat, &uniforms, &stats);

        // tablero
        const checker_model = Mat4.mul(
            Mat4.translate(.{ .x = -6, .y = 5, .z = 0 }),
            Mat4.mul(Mat4.rotateY(t * 0.5), uniformScale(1.5)),
        );
        render.drawMesh(&fb, sphere, checker_model, view_proj, &checker_mat, &uniforms, &stats);

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
