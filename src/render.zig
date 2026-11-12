const rl = @import("raylib");
const std = @import("std");
const math = @import("math.zig");
const Framebuffer = @import("framebuffer.zig").Framebuffer;

const Mat4 = math.Mat4;

pub const Mesh = struct {
    positions: []const rl.Vector3,
    normals: []const rl.Vector3,
    uvs: []const rl.Vector2,
    colors: []const rl.Vector3, // temporal, para depurar
    indices: []const [3]u32,

    pub fn deinit(self: *Mesh, allocator: std.mem.Allocator) void {
        allocator.free(self.positions);
        allocator.free(self.normals);
        allocator.free(self.uvs);
        allocator.free(self.colors);
        allocator.free(self.indices);
    }
};

// vértice en clip space antes del divide
pub const ClipVertex = struct {
    pos: rl.Vector4,
    color: rl.Vector3,
};

// vértice en pantalla antes de rasterizar
pub const ScreenVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    inv_w: f32,
    color_w: rl.Vector3,
};

pub const Stats = struct {
    drawn: u32 = 0,
    culled: u32 = 0,
};

pub fn lerpClip(a: ClipVertex, b: ClipVertex, t: f32) ClipVertex {
    return .{
        .pos = a.pos.lerp(b.pos, t),
        .color = a.color.lerp(b.color, t),
    };
}

pub fn clipNear(input: [3]ClipVertex, out: *[4]ClipVertex) usize {
    var count: usize = 0;
    for (0..3) |i| {
        const a = input[i];
        const b = input[(i + 1) % 3];
        const da = a.pos.z + a.pos.w;
        const db = b.pos.z + b.pos.w;

        if (da >= 0) {
            out[count] = a;
            count += 1;
        }
        if ((da >= 0) != (db >= 0)) {
            const t = da / (da - db);
            out[count] = lerpClip(a, b, t);
            count += 1;
        }
    }
    return count;
}

pub fn toScreenVertex(v: ClipVertex, width: i32, height: i32) ScreenVertex {
    const s = Mat4.toScreen(v.pos, width, height);
    const inv_w = 1.0 / v.pos.w;
    return .{
        .x = s.x,
        .y = s.y,
        .z = s.z,
        .inv_w = inv_w,
        .color_w = v.color.scale(inv_w),
    };
}

pub fn edge(ax: f32, ay: f32, bx: f32, by: f32, px: f32, py: f32) f32 {
    return (bx - ax) * (py - ay) - (by - ay) * (px - ax);
}

pub fn isBackFace(v0: ScreenVertex, v1: ScreenVertex, v2: ScreenVertex) bool {
    const area = edge(v0.x, v0.y, v1.x, v1.y, v2.x, v2.y);
    return area >= 0;
}

fn toColor(c: rl.Vector3) rl.Color {
    return rl.Color.init(
        @intFromFloat(std.math.clamp(c.x, 0, 1) * 255),
        @intFromFloat(std.math.clamp(c.y, 0, 1) * 255),
        @intFromFloat(std.math.clamp(c.z, 0, 1) * 255),
        255,
    );
}

pub fn rasterTriangle(fb: *Framebuffer, v0: ScreenVertex, v1: ScreenVertex, v2: ScreenVertex) void {
    const area = edge(v0.x, v0.y, v1.x, v1.y, v2.x, v2.y);
    if (area == 0) return;

    // bounding box
    const w: f32 = @floatFromInt(fb.width - 1);
    const h: f32 = @floatFromInt(fb.height - 1);
    const min_x: i32 = @intFromFloat(std.math.clamp(@floor(@min(v0.x, v1.x, v2.x)), 0, w));
    const max_x: i32 = @intFromFloat(std.math.clamp(@ceil(@max(v0.x, v1.x, v2.x)), 0, w));
    const min_y: i32 = @intFromFloat(std.math.clamp(@floor(@min(v0.y, v1.y, v2.y)), 0, h));
    const max_y: i32 = @intFromFloat(std.math.clamp(@ceil(@max(v0.y, v1.y, v2.y)), 0, h));

    var y = min_y;
    while (y <= max_y) : (y += 1) {
        const py = @as(f32, @floatFromInt(y)) + 0.5;
        var x = min_x;
        while (x <= max_x) : (x += 1) {
            const px = @as(f32, @floatFromInt(x)) + 0.5;

            const b0 = edge(v1.x, v1.y, v2.x, v2.y, px, py) / area;
            const b1 = edge(v2.x, v2.y, v0.x, v0.y, px, py) / area;
            const b2 = edge(v0.x, v0.y, v1.x, v1.y, px, py) / area;
            if (b0 < 0 or b1 < 0 or b2 < 0) continue;

            const z = b0 * v0.z + b1 * v1.z + b2 * v2.z;

            // corrección de perspectiva
            const inv_w = b0 * v0.inv_w + b1 * v1.inv_w + b2 * v2.inv_w;
            const color = v0.color_w.scale(b0)
                .add(v1.color_w.scale(b1))
                .add(v2.color_w.scale(b2))
                .scale(1.0 / inv_w);

            fb.setPixelDepth(x, y, z, toColor(color));
        }
    }
}

pub fn drawMesh(fb: *Framebuffer, mesh: Mesh, mvp: Mat4, stats: *Stats) void {
    for (mesh.indices) |tri| {
        var clip: [3]ClipVertex = undefined;
        for (0..3) |k| {
            const p = mesh.positions[tri[k]];
            clip[k] = .{
                .pos = Mat4.mulVec4(mvp, .{ .x = p.x, .y = p.y, .z = p.z, .w = 1 }),
                .color = mesh.colors[tri[k]],
            };
        }

        var poly: [4]ClipVertex = undefined;
        const n = clipNear(clip, &poly);
        if (n < 3) continue;

        var s: [4]ScreenVertex = undefined;
        for (0..n) |k| {
            s[k] = toScreenVertex(poly[k], fb.width, fb.height);
        }

        if (isBackFace(s[0], s[1], s[2])) {
            stats.culled += 1;
            continue;
        }

        rasterTriangle(fb, s[0], s[1], s[2]);
        if (n == 4) rasterTriangle(fb, s[0], s[2], s[3]);
        stats.drawn += 1;
    }
}
