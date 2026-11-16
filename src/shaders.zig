const rl = @import("raylib");
const std = @import("std");
const Texture = @import("texture.zig").Texture;

const Vector3 = rl.Vector3;

pub const Fragment = struct {
    world_pos: Vector3,
    normal: Vector3,
    uv: rl.Vector2,
};

pub const Uniforms = struct {
    light_pos: Vector3,
    light_color: Vector3,
    ambient: f32,
    time: f32 = 0,
};

pub const ShaderFn = *const fn (frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color;

pub const Material = struct {
    texture: *const Texture,
    shader: ShaderFn,
};

pub fn colorToVec3(c: rl.Color) Vector3 {
    return .{
        .x = @as(f32, @floatFromInt(c.r)) / 255.0,
        .y = @as(f32, @floatFromInt(c.g)) / 255.0,
        .z = @as(f32, @floatFromInt(c.b)) / 255.0,
    };
}

pub fn vec3ToColor(v: Vector3) rl.Color {
    return rl.Color.init(
        @intFromFloat(std.math.clamp(v.x, 0, 1) * 255),
        @intFromFloat(std.math.clamp(v.y, 0, 1) * 255),
        @intFromFloat(std.math.clamp(v.z, 0, 1) * 255),
        255,
    );
}

pub fn litTextured(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    const albedo = colorToVec3(mat.texture.sample(frag.uv.x, frag.uv.y));
    const l = u.light_pos.subtract(frag.world_pos).normalize();
    const diff = @max(frag.normal.dotProduct(l), 0);
    const light = Vector3{
        .x = u.ambient + u.light_color.x * diff,
        .y = u.ambient + u.light_color.y * diff,
        .z = u.ambient + u.light_color.z * diff,
    };
    return vec3ToColor(albedo.multiply(light));
}

pub fn emissive(frag: Fragment, mat: *const Material, u: *const Uniforms) rl.Color {
    _ = u;
    return mat.texture.sample(frag.uv.x, frag.uv.y);
}
