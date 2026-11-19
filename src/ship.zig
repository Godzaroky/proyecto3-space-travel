const rl = @import("raylib");
const std = @import("std");
const math = @import("math.zig");
const render = @import("render.zig");
const shaders = @import("shaders.zig");
const obj = @import("obj.zig");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Texture = @import("texture.zig").Texture;
const Camera = @import("camera.zig").Camera;

const Mat4 = math.Mat4;
const Vector3 = rl.Vector3;

// largo de la nave en unidades del mundo
const ship_length: f32 = 2.0;
// distancia delante de la cámara y cuánto más abajo
const follow_distance: f32 = 6.0;
const follow_drop: f32 = 1.6;
// giro extra si la nave apunta hacia otro lado (0, 90, 180 o -90)
const yaw_offset_deg: f32 = 0;
// inclinación lateral máxima al moverse con A / D
const max_roll: f32 = 0.45;

pub const Ship = struct {
    mesh: render.Mesh,
    texture: Texture,
    center: Vector3,
    scale: f32,
    radius: f32,
    roll: f32 = 0,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Ship {
        var mesh = obj.loadObj(allocator, io, path) catch |err| {
            std.debug.print("No se pudo cargar la nave: {s}\n", .{path});
            return err;
        };
        errdefer mesh.deinit(allocator);

        var lo = mesh.positions[0];
        var hi = mesh.positions[0];
        for (mesh.positions) |p| {
            lo = lo.min(p);
            hi = hi.max(p);
        }
        const extent = hi.subtract(lo);
        const largest = @max(extent.x, extent.y, extent.z);
        const s = ship_length / largest;

        return .{
            .mesh = mesh,
            .texture = try Texture.solid(allocator, rl.Color.white),
            .center = lo.add(extent.scale(0.5)),
            .scale = s,
            .radius = extent.length() * 0.5 * s,
        };
    }

    pub fn deinit(self: *Ship, allocator: std.mem.Allocator) void {
        self.mesh.deinit(allocator);
        self.texture.deinit(allocator);
    }

    pub fn update(self: *Ship, dt: f32) void {
        var target: f32 = 0;
        if (rl.isKeyDown(.a)) target += max_roll;
        if (rl.isKeyDown(.d)) target -= max_roll;
        const k = @min(dt * 6, 1);
        self.roll += (target - self.roll) * k;
    }

    pub fn position(camera: Camera) Vector3 {
        const f = camera.forward();
        const up = camera.right().crossProduct(f);
        return camera.position.add(f.scale(follow_distance)).subtract(up.scale(follow_drop));
    }

    pub fn modelMatrix(self: *const Ship, camera: Camera) Mat4 {
        const s = self.scale;
        const orientation = Mat4.mul(
            Mat4.rotateY(-camera.yaw),
            Mat4.mul(
                Mat4.rotateX(camera.pitch),
                Mat4.mul(
                    Mat4.rotateZ(self.roll),
                    Mat4.rotateY(std.math.degreesToRadians(yaw_offset_deg)),
                ),
            ),
        );
        return Mat4.mul(
            Mat4.translate(position(camera)),
            Mat4.mul(
                orientation,
                Mat4.mul(
                    Mat4.scale(.{ .x = s, .y = s, .z = s }),
                    Mat4.translate(self.center.negate()),
                ),
            ),
        );
    }

    pub fn draw(
        self: *const Ship,
        renderer: *render.Renderer,
        fb: *const Framebuffer,
        camera: Camera,
        view_proj: Mat4,
        uniforms: *const shaders.Uniforms,
    ) !void {
        const mat = shaders.Material{
            .texture = &self.texture,
            .shader = &shaders.ship,
        };
        try renderer.submit(fb, self.mesh, self.modelMatrix(camera), view_proj, mat, uniforms);
    }
};
