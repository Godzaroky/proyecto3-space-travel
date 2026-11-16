const rl = @import("raylib");
const std = @import("std");
const math = @import("math.zig");
const render = @import("render.zig");
const shaders = @import("shaders.zig");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Texture = @import("texture.zig").Texture;

const Mat4 = math.Mat4;
const Vector3 = rl.Vector3;

fn deg(d: f32) f32 {
    return std.math.degreesToRadians(d);
}

pub const Body = struct {
    name: []const u8,
    texture_path: [:0]const u8,
    shader: shaders.ShaderFn,
    parent: ?usize = null,
    radius: f32,
    orbit_radius: f32 = 0,
    orbit_speed: f32 = 0,
    orbit_phase: f32 = 0,
    orbit_tilt: f32 = 0,
    spin_speed: f32 = 0,
    axial_tilt: f32 = 0,
    position: Vector3 = .{ .x = 0, .y = 0, .z = 0 },
    spin: f32 = 0,
};

const body_defs = [_]Body{
    .{
        .name = "Sol",
        .texture_path = "assets/textures/sun.png",
        .shader = &shaders.emissive,
        .radius = 5,
        .spin_speed = 0.05,
    },
    .{
        .name = "Mercurio",
        .texture_path = "assets/textures/mercury.png",
        .shader = &shaders.litTextured,
        .parent = 0,
        .radius = 0.6,
        .orbit_radius = 10,
        .orbit_speed = 0.40,
        .orbit_phase = 0.5,
        .orbit_tilt = deg(7),
        .spin_speed = 0.1,
    },
    .{
        .name = "Tierra",
        .texture_path = "assets/textures/earth.png",
        .shader = &shaders.litTextured,
        .parent = 0,
        .radius = 1.2,
        .orbit_radius = 18,
        .orbit_speed = 0.20,
        .orbit_phase = 2.0,
        .spin_speed = 1.0,
        .axial_tilt = deg(23.4),
    },
    .{
        .name = "Luna",
        .texture_path = "assets/textures/moon.png",
        .shader = &shaders.litTextured,
        .parent = 2,
        .radius = 0.35,
        .orbit_radius = 2.5,
        .orbit_speed = 1.2,
        .orbit_tilt = deg(5),
        .spin_speed = 1.2,
    },
    .{
        .name = "Marte",
        .texture_path = "assets/textures/mars.png",
        .shader = &shaders.litTextured,
        .parent = 0,
        .radius = 0.9,
        .orbit_radius = 26,
        .orbit_speed = 0.15,
        .orbit_phase = 4.0,
        .orbit_tilt = deg(2),
        .spin_speed = 0.95,
        .axial_tilt = deg(25),
    },
    .{
        .name = "Jupiter",
        .texture_path = "assets/textures/jupiter.png",
        .shader = &shaders.litTextured,
        .parent = 0,
        .radius = 3.0,
        .orbit_radius = 40,
        .orbit_speed = 0.07,
        .orbit_phase = 1.0,
        .orbit_tilt = deg(1.3),
        .spin_speed = 2.0,
        .axial_tilt = deg(3),
    },
    .{
        .name = "Saturno",
        .texture_path = "assets/textures/saturn.png",
        .shader = &shaders.litTextured,
        .parent = 0,
        .radius = 2.5,
        .orbit_radius = 55,
        .orbit_speed = 0.05,
        .orbit_phase = 3.0,
        .orbit_tilt = deg(2.5),
        .spin_speed = 1.8,
        .axial_tilt = deg(26.7),
    },
};

pub const body_count = body_defs.len;

pub const SolarSystem = struct {
    bodies: [body_count]Body,
    textures: [body_count]Texture,

    pub fn init(allocator: std.mem.Allocator) !SolarSystem {
        var self: SolarSystem = .{
            .bodies = body_defs,
            .textures = undefined,
        };

        var loaded: usize = 0;
        errdefer for (self.textures[0..loaded]) |*tex| tex.deinit(allocator);

        for (self.bodies, 0..) |body, i| {
            self.textures[i] = Texture.load(allocator, body.texture_path) catch |err| {
                std.debug.print("No se pudo cargar {s}\n", .{body.texture_path});
                return err;
            };
            loaded += 1;
        }

        self.update(0);
        return self;
    }

    pub fn deinit(self: *SolarSystem, allocator: std.mem.Allocator) void {
        for (&self.textures) |*tex| tex.deinit(allocator);
    }

    pub fn update(self: *SolarSystem, t: f32) void {
        for (&self.bodies) |*body| {
            const center = if (body.parent) |p| self.bodies[p].position else Vector3.zero();
            const angle = body.orbit_phase + t * body.orbit_speed;

            const flat = Vector3{
                .x = @cos(angle) * body.orbit_radius,
                .y = 0,
                .z = -@sin(angle) * body.orbit_radius,
            };
            const tilted = Vector3{
                .x = flat.x,
                .y = -flat.z * @sin(body.orbit_tilt),
                .z = flat.z * @cos(body.orbit_tilt),
            };

            body.position = center.add(tilted);
            body.spin = t * body.spin_speed;
        }
    }

    pub fn modelMatrix(body: Body) Mat4 {
        return Mat4.mul(
            Mat4.translate(body.position),
            Mat4.mul(
                Mat4.rotateZ(body.axial_tilt),
                Mat4.mul(
                    Mat4.rotateY(body.spin),
                    Mat4.scale(.{ .x = body.radius, .y = body.radius, .z = body.radius }),
                ),
            ),
        );
    }

    pub fn sunPosition(self: *const SolarSystem) Vector3 {
        return self.bodies[0].position;
    }

    pub fn draw(
        self: *const SolarSystem,
        fb: *Framebuffer,
        sphere: render.Mesh,
        view_proj: Mat4,
        uniforms: *const shaders.Uniforms,
        stats: *render.Stats,
    ) void {
        for (self.bodies, 0..) |body, i| {
            const mat = shaders.Material{
                .texture = &self.textures[i],
                .shader = body.shader,
            };
            render.drawMesh(fb, sphere, modelMatrix(body), view_proj, &mat, uniforms, stats);
        }
    }
};
