const rl = @import("raylib");
const std = @import("std");
const math = @import("math.zig");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const shaders = @import("shaders.zig");

const Mat4 = math.Mat4;
const Vector3 = rl.Vector3;
const Material = shaders.Material;
const Uniforms = shaders.Uniforms;

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

// datos que se interpolan por pixel
pub const Varyings = struct {
    world_pos: Vector3,
    normal: Vector3,
    uv: rl.Vector2,

    pub fn scale(self: Varyings, f: f32) Varyings {
        return .{
            .world_pos = self.world_pos.scale(f),
            .normal = self.normal.scale(f),
            .uv = self.uv.scale(f),
        };
    }

    pub fn add(self: Varyings, o: Varyings) Varyings {
        return .{
            .world_pos = self.world_pos.add(o.world_pos),
            .normal = self.normal.add(o.normal),
            .uv = self.uv.add(o.uv),
        };
    }

    pub fn lerp(self: Varyings, o: Varyings, t: f32) Varyings {
        return .{
            .world_pos = self.world_pos.lerp(o.world_pos, t),
            .normal = self.normal.lerp(o.normal, t),
            .uv = self.uv.lerp(o.uv, t),
        };
    }
};

// vértice en clip space antes del divide
pub const ClipVertex = struct {
    pos: rl.Vector4,
    v: Varyings,
};

// vértice en pantalla antes de rasterizar
pub const ScreenVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    inv_w: f32,
    v_w: Varyings,
};

pub const Stats = struct {
    drawn: u32 = 0,
    culled: u32 = 0,
};

pub fn lerpClip(a: ClipVertex, b: ClipVertex, t: f32) ClipVertex {
    return .{
        .pos = a.pos.lerp(b.pos, t),
        .v = a.v.lerp(b.v, t),
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

pub fn toScreenVertex(c: ClipVertex, width: i32, height: i32) ScreenVertex {
    const s = Mat4.toScreen(c.pos, width, height);
    const inv_w = 1.0 / c.pos.w;
    return .{
        .x = s.x,
        .y = s.y,
        .z = s.z,
        .inv_w = inv_w,
        .v_w = c.v.scale(inv_w),
    };
}

pub fn edge(ax: f32, ay: f32, bx: f32, by: f32, px: f32, py: f32) f32 {
    return (bx - ax) * (py - ay) - (by - ay) * (px - ax);
}

pub fn isBackFace(v0: ScreenVertex, v1: ScreenVertex, v2: ScreenVertex) bool {
    const area = edge(v0.x, v0.y, v1.x, v1.y, v2.x, v2.y);
    return area >= 0;
}

pub fn rasterTriangle(
    fb: *Framebuffer,
    v0: ScreenVertex,
    v1: ScreenVertex,
    v2: ScreenVertex,
    mat: *const Material,
    u: *const Uniforms,
) void {
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

            // early-z
            const i: usize = @intCast(y * fb.width + x);
            if (z >= fb.depth[i]) continue;

            // corrección de perspectiva
            const inv_w = b0 * v0.inv_w + b1 * v1.inv_w + b2 * v2.inv_w;
            const v = v0.v_w.scale(b0)
                .add(v1.v_w.scale(b1))
                .add(v2.v_w.scale(b2))
                .scale(1.0 / inv_w);

            const frag = shaders.Fragment{
                .world_pos = v.world_pos,
                .normal = v.normal.normalize(),
                .uv = v.uv,
            };

            const color = mat.shader(frag, mat, u);

            if (mat.transparent) {
                if (color.a == 0) continue;
                fb.color[i] = blend(fb.color[i], color);
            } else {
                fb.depth[i] = z;
                fb.color[i] = color;
            }
        }
    }
}

fn blend(dst: rl.Color, src: rl.Color) rl.Color {
    const a: u32 = src.a;
    const inv: u32 = 255 - a;
    return rl.Color.init(
        @intCast((@as(u32, src.r) * a + @as(u32, dst.r) * inv) / 255),
        @intCast((@as(u32, src.g) * a + @as(u32, dst.g) * inv) / 255),
        @intCast((@as(u32, src.b) * a + @as(u32, dst.b) * inv) / 255),
        255,
    );
}

pub fn drawMesh(
    fb: *Framebuffer,
    mesh: Mesh,
    model: Mat4,
    view_proj: Mat4,
    mat: *const Material,
    u: *const Uniforms,
    stats: *Stats,
) void {
    for (mesh.indices) |tri| {
        var clip: [3]ClipVertex = undefined;
        for (0..3) |k| {
            const idx = tri[k];
            var p = mesh.positions[idx];
            var nrm = mesh.normals[idx];

            if (mat.vertex) |vertex_fn| {
                const out = vertex_fn(p, nrm, u);
                p = out.pos;
                nrm = out.normal;
            }

            const world = Mat4.mulVec4(model, .{ .x = p.x, .y = p.y, .z = p.z, .w = 1 });
            const world_n = Mat4.mulVec4(model, .{ .x = nrm.x, .y = nrm.y, .z = nrm.z, .w = 0 });

            clip[k] = .{
                .pos = Mat4.mulVec4(view_proj, world),
                .v = .{
                    .world_pos = .{ .x = world.x, .y = world.y, .z = world.z },
                    .normal = (Vector3{ .x = world_n.x, .y = world_n.y, .z = world_n.z }).normalize(),
                    .uv = mesh.uvs[idx],
                },
            };
        }

        var poly: [4]ClipVertex = undefined;
        const n = clipNear(clip, &poly);
        if (n < 3) continue;

        var s: [4]ScreenVertex = undefined;
        for (0..n) |k| {
            s[k] = toScreenVertex(poly[k], fb.width, fb.height);
        }

        if (!mat.double_sided and isBackFace(s[0], s[1], s[2])) {
            stats.culled += 1;
            continue;
        }

        rasterTriangle(fb, s[0], s[1], s[2], mat, u);
        if (n == 4) rasterTriangle(fb, s[0], s[2], s[3], mat, u);
        stats.drawn += 1;
    }
}
