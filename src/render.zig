const rl = @import("raylib");
const std = @import("std");
const math = @import("math.zig");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const shaders = @import("shaders.zig");
const Skybox = @import("skybox.zig").Skybox;
const Camera = @import("camera.zig").Camera;

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
    color: Vector3,

    pub fn scale(self: Varyings, f: f32) Varyings {
        return .{
            .world_pos = self.world_pos.scale(f),
            .normal = self.normal.scale(f),
            .uv = self.uv.scale(f),
            .color = self.color.scale(f),
        };
    }

    pub fn add(self: Varyings, o: Varyings) Varyings {
        return .{
            .world_pos = self.world_pos.add(o.world_pos),
            .normal = self.normal.add(o.normal),
            .uv = self.uv.add(o.uv),
            .color = self.color.add(o.color),
        };
    }

    pub fn lerp(self: Varyings, o: Varyings, t: f32) Varyings {
        return .{
            .world_pos = self.world_pos.lerp(o.world_pos, t),
            .normal = self.normal.lerp(o.normal, t),
            .uv = self.uv.lerp(o.uv, t),
            .color = self.color.lerp(o.color, t),
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

pub const Triangle = struct {
    v: [3]ScreenVertex,
    mat: Material,
};

pub const Stats = struct {
    drawn: u32 = 0,
    culled: u32 = 0,
    bodies_culled: u32 = 0,
    lod: [4]u32 = @splat(0),
};

pub const SkyPass = struct {
    skybox: *const Skybox,
    camera: *const Camera,
    aspect: f32,
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

// rasterización

const Bounds = struct {
    min_x: i32,
    max_x: i32,
    min_y: i32,
    max_y: i32,
    inv_area: f32,
};

fn triangleBounds(tri: *const Triangle, fb: *const Framebuffer) ?Bounds {
    const v0 = tri.v[0];
    const v1 = tri.v[1];
    const v2 = tri.v[2];
    const area = edge(v0.x, v0.y, v1.x, v1.y, v2.x, v2.y);
    if (area == 0) return null;

    const w: f32 = @floatFromInt(fb.width - 1);
    const h: f32 = @floatFromInt(fb.height - 1);
    const lo_x = @floor(@min(v0.x, v1.x, v2.x));
    const hi_x = @ceil(@max(v0.x, v1.x, v2.x));
    const lo_y = @floor(@min(v0.y, v1.y, v2.y));
    const hi_y = @ceil(@max(v0.y, v1.y, v2.y));
    if (hi_x < 0 or hi_y < 0 or lo_x > w or lo_y > h) return null;

    return .{
        .min_x = @intFromFloat(std.math.clamp(lo_x, 0, w)),
        .max_x = @intFromFloat(std.math.clamp(hi_x, 0, w)),
        .min_y = @intFromFloat(std.math.clamp(lo_y, 0, h)),
        .max_y = @intFromFloat(std.math.clamp(hi_y, 0, h)),
        .inv_area = 1.0 / area,
    };
}

fn rasterRows(fb: *Framebuffer, tri: *const Triangle, bb: Bounds, y0: i32, y1: i32, u: *const Uniforms) void {
    const v0 = tri.v[0];
    const v1 = tri.v[1];
    const v2 = tri.v[2];
    const mat = &tri.mat;

    // paso de cada función de borde al avanzar un pixel en x
    const step0 = -(v2.y - v1.y);
    const step1 = -(v0.y - v2.y);
    const step2 = -(v1.y - v0.y);

    const px0 = @as(f32, @floatFromInt(bb.min_x)) + 0.5;

    var y = y0;
    while (y <= y1) : (y += 1) {
        const py = @as(f32, @floatFromInt(y)) + 0.5;
        var e0 = edge(v1.x, v1.y, v2.x, v2.y, px0, py);
        var e1 = edge(v2.x, v2.y, v0.x, v0.y, px0, py);
        var e2 = edge(v0.x, v0.y, v1.x, v1.y, px0, py);

        const row: usize = @intCast(y * fb.width);
        var x = bb.min_x;
        while (x <= bb.max_x) : ({
            x += 1;
            e0 += step0;
            e1 += step1;
            e2 += step2;
        }) {
            const b0 = e0 * bb.inv_area;
            const b1 = e1 * bb.inv_area;
            const b2 = e2 * bb.inv_area;
            if (b0 < 0 or b1 < 0 or b2 < 0) continue;

            const z = b0 * v0.z + b1 * v1.z + b2 * v2.z;

            // early-z
            const i = row + @as(usize, @intCast(x));
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
                .color = v.color,
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

// cada hilo procesa franjas de filas intercaladas
const chunk_rows: i32 = 8;
const max_threads = 32;

const Job = struct {
    fb: *Framebuffer,
    triangles: []const Triangle,
    u: *const Uniforms,
    sky: ?SkyPass,
    thread_count: usize,
};

fn worker(job: *const Job, t: usize) void {
    const n: i32 = @intCast(job.thread_count);
    const ti: i32 = @intCast(t);
    const height = job.fb.height;

    if (job.sky) |sky| {
        var c = ti;
        while (c * chunk_rows < height) : (c += n) {
            const y0 = c * chunk_rows;
            sky.skybox.drawRows(job.fb, sky.camera, sky.aspect, y0, @min(height, y0 + chunk_rows));
        }
    }

    for (job.triangles) |*tri| {
        const bb = triangleBounds(tri, job.fb) orelse continue;
        var c = @divFloor(bb.min_y, chunk_rows);
        c += @mod(ti - @mod(c, n), n);
        while (c * chunk_rows <= bb.max_y) : (c += n) {
            const y0 = @max(bb.min_y, c * chunk_rows);
            const y1 = @min(bb.max_y, c * chunk_rows + chunk_rows - 1);
            rasterRows(job.fb, tri, bb, y0, y1, job.u);
        }
    }
}

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    triangles: std.ArrayList(Triangle) = .empty,
    thread_count: usize,
    stats: Stats = .{},

    pub fn init(allocator: std.mem.Allocator) Renderer {
        const cpus = std.Thread.getCpuCount() catch 4;
        return .{
            .allocator = allocator,
            .thread_count = std.math.clamp(cpus, 1, max_threads),
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.triangles.deinit(self.allocator);
    }

    pub fn begin(self: *Renderer) void {
        self.triangles.clearRetainingCapacity();
        self.stats = .{};
    }

    // etapa de geometría: transforma, recorta y descarta triángulos
    pub fn submit(
        self: *Renderer,
        fb: *const Framebuffer,
        mesh: Mesh,
        model: Mat4,
        view_proj: Mat4,
        mat: Material,
        u: *const Uniforms,
    ) !void {
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
                        .color = mesh.colors[idx],
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
                self.stats.culled += 1;
                continue;
            }

            try self.triangles.append(self.allocator, .{ .v = .{ s[0], s[1], s[2] }, .mat = mat });
            if (n == 4) {
                try self.triangles.append(self.allocator, .{ .v = .{ s[0], s[2], s[3] }, .mat = mat });
            }
            self.stats.drawn += 1;
        }
    }

    // etapa de rasterización en paralelo
    pub fn flush(self: *Renderer, fb: *Framebuffer, u: *const Uniforms, sky: ?SkyPass) void {
        const job = Job{
            .fb = fb,
            .triangles = self.triangles.items,
            .u = u,
            .sky = sky,
            .thread_count = self.thread_count,
        };

        var threads: [max_threads]?std.Thread = @splat(null);
        for (1..self.thread_count) |t| {
            threads[t] = std.Thread.spawn(.{}, worker, .{ &job, t }) catch null;
        }

        worker(&job, 0);

        // si un hilo no se pudo crear, su parte se hace aquí
        for (1..self.thread_count) |t| {
            if (threads[t]) |thread| thread.join() else worker(&job, t);
        }
    }
};
