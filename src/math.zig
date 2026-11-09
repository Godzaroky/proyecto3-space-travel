const rl = @import("raylib");
const std = @import("std");

const Vector4 = rl.Vector4;
const Vector3 = rl.Vector3;

pub const Mat4 = struct {
    m: [4][4]f32,

    pub fn identity() Mat4 {
        return Mat4{
            .m = .{
                .{ 1, 0, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var r: Mat4 = undefined;
        for (0..4) |i| {
            for (0..4) |j| {
                var sum: f32 = 0;
                for (0..4) |k| {
                    sum += a.m[i][k] * b.m[k][j];
                }
                r.m[i][j] = sum;
            }
        }
        return r;
    }

    pub fn mulVec4(a: Mat4, v: Vector4) Vector4 {
        const x = a.m[0][0] * v.x + a.m[0][1] * v.y + a.m[0][2] * v.z + a.m[0][3] * v.w;
        const y = a.m[1][0] * v.x + a.m[1][1] * v.y + a.m[1][2] * v.z + a.m[1][3] * v.w;
        const z = a.m[2][0] * v.x + a.m[2][1] * v.y + a.m[2][2] * v.z + a.m[2][3] * v.w;
        const w = a.m[3][0] * v.x + a.m[3][1] * v.y + a.m[3][2] * v.z + a.m[3][3] * v.w;
        return Vector4{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn translate(t: Vector3) Mat4 {
        return Mat4{
            .m = .{
                .{ 1, 0, 0, t.x },
                .{ 0, 1, 0, t.y },
                .{ 0, 0, 1, t.z },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn scale(s: Vector3) Mat4 {
        return Mat4{
            .m = .{
                .{ s.x, 0, 0, 0 },
                .{ 0, s.y, 0, 0 },
                .{ 0, 0, s.z, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotateX(a: f32) Mat4 {
        const c = @cos(a);
        const s = @sin(a);
        return Mat4{
            .m = .{
                .{ 1, 0, 0, 0 },
                .{ 0, c, -s, 0 },
                .{ 0, s, c, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotateY(a: f32) Mat4 {
        const c = @cos(a);
        const s = @sin(a);
        return Mat4{
            .m = .{
                .{ c, 0, s, 0 },
                .{ 0, 1, 0, 0 },
                .{ -s, 0, c, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotateZ(a: f32) Mat4 {
        const c = @cos(a);
        const s = @sin(a);
        return Mat4{
            .m = .{
                .{ c, -s, 0, 0 },
                .{ s, c, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn lookAt(eye: Vector3, center: Vector3, up: Vector3) Mat4 {
        const f = center.subtract(eye).normalize();
        const s = f.crossProduct(up).normalize();
        const u = s.crossProduct(f);

        return Mat4{
            .m = .{
                .{ s.x, s.y, s.z, -s.dotProduct(eye) },
                .{ u.x, u.y, u.z, -u.dotProduct(eye) },
                .{ -f.x, -f.y, -f.z, f.dotProduct(eye) },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / @tan(fov_y / 2.0);
        return Mat4{
            .m = .{
                .{ f / aspect, 0, 0, 0 },
                .{ 0, f, 0, 0 },
                .{ 0, 0, (far + near) / (near - far), (2 * far * near) / (near - far) },
                .{ 0, 0, -1, 0 },
            },
        };
    }

    // clip -> pantalla
    pub fn toScreen(clip: Vector4, width: i32, height: i32) Vector3 {
        const w: f32 = @floatFromInt(width);
        const h: f32 = @floatFromInt(height);
        const inv_w = 1.0 / clip.w;

        const sx = (clip.x * inv_w + 1.0) * 0.5 * w;
        const sy = (1.0 - clip.y * inv_w) * 0.5 * h;
        const sz = clip.z * inv_w;
        return .{ .x = sx, .y = sy, .z = sz };
    }
};
