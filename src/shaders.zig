const rl = @import("raylib");
const std = @import("std");
const Texture = @import("texture.zig").Texture;
const noise = @import("noise.zig");

const Vector3 = rl.Vector3;

pub const Fragment = struct {
    world_pos: Vector3,
    normal: Vector3,
    uv: rl.Vector2,
    color: Vector3,
};

pub const Uniforms = struct {
    light_pos: Vector3,
    light_color: Vector3,
    ambient: f32,
    time: f32 = 0,
    camera_pos: Vector3 = .{ .x = 0, .y = 0, .z = 0 },
};

pub const VertexOut = struct {
    pos: Vector3,
    normal: Vector3,
};

pub const ShaderFn = *const fn (frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color;
pub const VertexFn = *const fn (pos: Vector3, normal: Vector3, u: *const Uniforms) VertexOut;

pub const Material = struct {
    texture: *const Texture,
    texture2: ?*const Texture = null,
    shader: ShaderFn,
    vertex: ?VertexFn = null,
    transparent: bool = false,
    double_sided: bool = false,
};

// utilidades

pub fn colorToVec3(c: rl.Color) Vector3 {
    return .{
        .x = @as(f32, @floatFromInt(c.r)) / 255.0,
        .y = @as(f32, @floatFromInt(c.g)) / 255.0,
        .z = @as(f32, @floatFromInt(c.b)) / 255.0,
    };
}

pub fn vec3ToColor(v: Vector3) rl.Color {
    return vec3ToColorAlpha(v, 1);
}

pub fn vec3ToColorAlpha(v: Vector3, a: f32) rl.Color {
    return rl.Color.init(
        @intFromFloat(std.math.clamp(v.x, 0, 1) * 255),
        @intFromFloat(std.math.clamp(v.y, 0, 1) * 255),
        @intFromFloat(std.math.clamp(v.z, 0, 1) * 255),
        @intFromFloat(std.math.clamp(a, 0, 1) * 255),
    );
}

fn sampleVec3(tex: *const Texture, uv: rl.Vector2) Vector3 {
    return colorToVec3(tex.sample(uv.x, uv.y));
}

fn smoothstep(e0: f32, e1: f32, x: f32) f32 {
    const t = std.math.clamp((x - e0) / (e1 - e0), 0, 1);
    return t * t * (3 - 2 * t);
}

fn mix(a: Vector3, b: Vector3, t: f32) Vector3 {
    return a.lerp(b, t);
}

fn splat(v: f32) Vector3 {
    return .{ .x = v, .y = v, .z = v };
}

fn rotateAroundY(v: Vector3, a: f32) Vector3 {
    const c = @cos(a);
    const s = @sin(a);
    return .{ .x = v.x * c - v.z * s, .y = v.y, .z = v.x * s + v.z * c };
}

fn lightDir(frag: Fragment, u: *const Uniforms) Vector3 {
    return u.light_pos.subtract(frag.world_pos).normalize();
}

fn viewDir(frag: Fragment, u: *const Uniforms) Vector3 {
    return u.camera_pos.subtract(frag.world_pos).normalize();
}

fn diffuse(frag: Fragment, u: *const Uniforms) f32 {
    return @max(frag.normal.dotProduct(lightDir(frag, u)), 0);
}

fn shade(albedo: Vector3, diff: f32, u: *const Uniforms) Vector3 {
    return albedo.multiply(splat(u.ambient).add(u.light_color.scale(diff)));
}

// shaders básicos

pub fn litTextured(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    const albedo = sampleVec3(mat.texture, frag.uv);
    return vec3ToColor(shade(albedo, diffuse(frag, u), u));
}

pub fn emissive(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    _ = u;
    return mat.texture.sample(frag.uv.x, frag.uv.y);
}

// sol: superficie animada con ruido
pub fn sun(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    const base = sampleVec3(mat.texture, frag.uv);
    const t = u.time;
    const p = frag.normal.scale(4).add(.{ .x = t * 0.15, .y = -t * 0.1, .z = t * 0.05 });
    const n = noise.fbm(p, 4);
    const pulse = 0.9 + 0.1 * @sin(t * 1.5);
    const glow = Vector3{ .x = 1.0, .y = 0.55, .z = 0.1 };
    const color = base.scale((0.7 + 0.7 * n) * pulse).add(glow.scale(smoothstep(0.55, 0.8, n) * 0.4));
    return vec3ToColor(color);
}

// mercurio: cel shading con contorno
pub fn mercury(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    const albedo = sampleVec3(mat.texture, frag.uv);
    const diff = diffuse(frag, u);
    const levels: f32 = 4;
    const toon = @ceil(diff * levels) / levels;

    const facing = frag.normal.dotProduct(viewDir(frag, u));
    if (facing < 0.25) return vec3ToColor(splat(0.02));

    return vec3ToColor(shade(albedo, toon, u));
}

// tierra: día y noche, nubes animadas
pub fn earth(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    const day = sampleVec3(mat.texture, frag.uv);
    const night = if (mat.texture2) |tex2| sampleVec3(tex2, frag.uv) else splat(0);
    const diff = diffuse(frag, u);

    const cloud_p = rotateAroundY(frag.normal, u.time * 0.05).scale(3);
    const cloud = smoothstep(0.5, 0.75, noise.fbm(cloud_p, 4));

    const lit_day = shade(mix(day, splat(1), cloud * 0.9), diff, u);
    const darkness = 1 - smoothstep(0, 0.25, diff);
    const lights = night.scale(darkness * (1 - cloud) * 1.2);
    return vec3ToColor(lit_day.add(lights));
}

// luna: el vertex shader deforma la geometría
pub fn moonVertex(pos: Vector3, normal: Vector3, u: *const Uniforms) VertexOut {
    _ = u;
    const n = noise.fbm(normal.scale(3), 4);
    const bump = (n - 0.5) * 0.3;
    return .{
        .pos = pos.scale(1 + bump),
        .normal = normal,
    };
}

pub fn moon(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    const albedo = sampleVec3(mat.texture, frag.uv);
    const detail = 0.75 + 0.5 * noise.fbm(frag.normal.scale(12), 3);
    return vec3ToColor(shade(albedo.scale(detail), diffuse(frag, u), u));
}

// marte: tormentas de polvo y atmósfera
pub fn mars(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    const albedo = sampleVec3(mat.texture, frag.uv);
    const diff = diffuse(frag, u);
    const t = u.time;

    const storm_p = rotateAroundY(frag.normal, t * 0.15).scale(4).add(.{ .x = 0, .y = t * 0.1, .z = 0 });
    const storm = smoothstep(0.55, 0.8, noise.fbm(storm_p, 4));
    const dust = Vector3{ .x = 0.85, .y = 0.55, .z = 0.35 };
    const surface = shade(mix(albedo, dust, storm * 0.7), diff, u);

    const facing = @max(frag.normal.dotProduct(viewDir(frag, u)), 0);
    const rim = std.math.pow(f32, 1 - facing, 3);
    const atmosphere = Vector3{ .x = 1.0, .y = 0.5, .z = 0.3 };
    return vec3ToColor(surface.add(atmosphere.scale(rim * 0.6 * (0.3 + diff))));
}

// júpiter: bandas que fluyen
pub fn jupiter(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    const t = u.time;
    const v = frag.uv.y;
    const flow = @sin(v * 12) * t * 0.01 + @sin(v * 40 + t * 0.5) * 0.004;
    const turb_p = Vector3{ .x = frag.uv.x * 8, .y = v * 30, .z = t * 0.2 };
    const turb = (noise.fbm(turb_p, 3) - 0.5) * 0.015;
    const uv = rl.Vector2{ .x = frag.uv.x + flow + turb, .y = v + turb * 0.5 };
    const albedo = sampleVec3(mat.texture, uv);
    return vec3ToColor(shade(albedo, diffuse(frag, u), u));
}

// anillos de saturno: transparentes y procedurales
pub fn saturnRing(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    _ = mat;
    const r = frag.uv.x;
    const bands = noise.fbm(.{ .x = r * 40, .y = 0, .z = 0 }, 3);
    const density = 0.35 + 0.65 * bands;

    const cassini = 1 - smoothstep(0.55, 0.58, r) * (1 - smoothstep(0.62, 0.65, r));
    const edges = smoothstep(0, 0.05, r) * (1 - smoothstep(0.95, 1, r));
    const alpha = density * cassini * edges * 0.9;

    const base = Vector3{ .x = 0.85, .y = 0.75, .z = 0.6 };
    const light = @abs(frag.normal.dotProduct(lightDir(frag, u))) * 0.8 + 0.2;
    return vec3ToColorAlpha(base.scale(light * (0.7 + 0.3 * bands)), alpha);
}

// nave: color del material con brillo especular
pub fn ship(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    const albedo = frag.color.multiply(sampleVec3(mat.texture, frag.uv));
    const l = lightDir(frag, u);
    const v = viewDir(frag, u);
    const diff = @max(frag.normal.dotProduct(l), 0);

    const h = l.add(v).normalize();
    const spec = std.math.pow(f32, @max(frag.normal.dotProduct(h), 0), 32) * 0.6;

    const facing = @max(frag.normal.dotProduct(v), 0);
    const rim = std.math.pow(f32, 1 - facing, 4) * 0.15;

    // la nave usa más luz ambiental para que se vea aunque el sol quede detrás
    const base = albedo.multiply(splat(0.25).add(u.light_color.scale(diff)));
    const lit = base.add(u.light_color.scale(spec * diff)).add(splat(rim));
    return vec3ToColor(lit);
}
