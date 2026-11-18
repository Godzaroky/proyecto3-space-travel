const rl = @import("raylib");
const std = @import("std");
const noise = @import("noise.zig");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Camera = @import("camera.zig").Camera;

const Vector3 = rl.Vector3;

const galactic_normal = Vector3{ .x = 0.28, .y = 0.92, .z = 0.27 };

fn hash(a: u32, b: u32, c: u32, seed: u32) f32 {
    var h: u32 = a *% 0x8da6b343 +% b *% 0xd8163841 +% c *% 0xcb1ab31f +% seed *% 0x165667b1;
    h ^= h >> 15;
    h *%= 0x2c1b3c6d;
    h ^= h >> 12;
    h *%= 0x297a2d39;
    h ^= h >> 15;
    return @as(f32, @floatFromInt(h & 0xffffff)) / 16777215.0;
}

fn faceDir(face: usize, uc: f32, vc: f32) Vector3 {
    return switch (face) {
        0 => .{ .x = 1, .y = -vc, .z = -uc },
        1 => .{ .x = -1, .y = -vc, .z = uc },
        2 => .{ .x = uc, .y = 1, .z = vc },
        3 => .{ .x = uc, .y = -1, .z = -vc },
        4 => .{ .x = uc, .y = -vc, .z = 1 },
        else => .{ .x = -uc, .y = -vc, .z = -1 },
    };
}

fn toColor(c: Vector3) rl.Color {
    return rl.Color.init(
        @intFromFloat(std.math.clamp(c.x, 0, 1) * 255),
        @intFromFloat(std.math.clamp(c.y, 0, 1) * 255),
        @intFromFloat(std.math.clamp(c.z, 0, 1) * 255),
        255,
    );
}

fn skyColor(d: Vector3, face: u32, x: u32, y: u32) Vector3 {
    var col = Vector3{ .x = 0.004, .y = 0.004, .z = 0.012 };

    // vía láctea
    const band = d.dotProduct(galactic_normal.normalize());
    const w = @exp(-band * band * 18);
    if (w > 0.01) {
        const n = noise.fbm(d.scale(5), 4);
        const glow = w * (0.05 + 0.3 * n * n);
        col = col.add((Vector3{ .x = 0.55, .y = 0.6, .z = 0.85 }).scale(glow * 0.5));
    }

    // estrellas
    const density = 0.0025 + 0.012 * w;
    if (hash(face, x, y, 1) < density) {
        const b = 0.15 + 0.85 * std.math.pow(f32, hash(face, x, y, 2), 4);
        const kind = hash(face, x, y, 3);
        const tint = if (kind < 0.15)
            Vector3{ .x = 0.7, .y = 0.8, .z = 1.0 }
        else if (kind < 0.3)
            Vector3{ .x = 1.0, .y = 0.85, .z = 0.6 }
        else
            Vector3{ .x = 1.0, .y = 1.0, .z = 1.0 };
        col = col.add(tint.scale(b));
    }

    return col;
}

pub const Skybox = struct {
    res: usize,
    faces: [6][]rl.Color,

    pub fn init(allocator: std.mem.Allocator, res: usize) !Skybox {
        var self = Skybox{ .res = res, .faces = undefined };

        var allocated: usize = 0;
        errdefer for (self.faces[0..allocated]) |face| allocator.free(face);

        const res_f: f32 = @floatFromInt(res);
        for (0..6) |f| {
            self.faces[f] = try allocator.alloc(rl.Color, res * res);
            allocated += 1;

            for (0..res) |y| {
                const vc = (@as(f32, @floatFromInt(y)) + 0.5) / res_f * 2 - 1;
                for (0..res) |x| {
                    const uc = (@as(f32, @floatFromInt(x)) + 0.5) / res_f * 2 - 1;
                    const d = faceDir(f, uc, vc).normalize();
                    const col = skyColor(d, @intCast(f), @intCast(x), @intCast(y));
                    self.faces[f][y * res + x] = toColor(col);
                }
            }
        }

        return self;
    }

    pub fn deinit(self: *Skybox, allocator: std.mem.Allocator) void {
        for (self.faces) |face| allocator.free(face);
    }

    pub fn sample(self: *const Skybox, d: Vector3) rl.Color {
        const ax = @abs(d.x);
        const ay = @abs(d.y);
        const az = @abs(d.z);

        var face: usize = undefined;
        var u: f32 = undefined;
        var v: f32 = undefined;

        if (ax >= ay and ax >= az) {
            face = if (d.x > 0) 0 else 1;
            u = if (d.x > 0) -d.z / ax else d.z / ax;
            v = -d.y / ax;
        } else if (ay >= az) {
            face = if (d.y > 0) 2 else 3;
            u = d.x / ay;
            v = if (d.y > 0) d.z / ay else -d.z / ay;
        } else {
            face = if (d.z > 0) 4 else 5;
            u = if (d.z > 0) d.x / az else -d.x / az;
            v = -d.y / az;
        }

        const res_f: f32 = @floatFromInt(self.res);
        const max_i = self.res - 1;
        const x: usize = @min(@as(usize, @intFromFloat(std.math.clamp((u + 1) * 0.5 * res_f, 0, res_f))), max_i);
        const y: usize = @min(@as(usize, @intFromFloat(std.math.clamp((v + 1) * 0.5 * res_f, 0, res_f))), max_i);
        return self.faces[face][y * self.res + x];
    }

    pub fn draw(self: *const Skybox, fb: *Framebuffer, camera: *const Camera, aspect: f32) void {
        const forward = camera.forward();
        const right = camera.right();
        const up = right.crossProduct(forward);

        const th = @tan(camera.fov_y * 0.5);
        const w: f32 = @floatFromInt(fb.width);
        const h: f32 = @floatFromInt(fb.height);

        const step_x = right.scale(2.0 / w * th * aspect);
        const step_y = up.scale(-2.0 / h * th);
        const origin = forward
            .add(right.scale((1.0 / w - 1.0) * th * aspect))
            .add(up.scale((1.0 - 1.0 / h) * th));

        const width: usize = @intCast(fb.width);
        const height: usize = @intCast(fb.height);

        var row = origin;
        for (0..height) |y| {
            var d = row;
            for (0..width) |x| {
                fb.color[y * width + x] = self.sample(d);
                d = d.add(step_x);
            }
            row = row.add(step_y);
        }
    }
};
