const rl = @import("raylib");

const Vector3 = rl.Vector3;

fn hash(x: i32, y: i32, z: i32) f32 {
    var h: u32 = @bitCast(x *% 374761393 +% y *% 668265263 +% z *% 1274126177);
    h = (h ^ (h >> 13)) *% 1274126177;
    h ^= h >> 16;
    return @as(f32, @floatFromInt(h & 0xffff)) / 65535.0;
}

fn fade(t: f32) f32 {
    return t * t * (3 - 2 * t);
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

// value noise en [0, 1]
pub fn noise3(p: Vector3) f32 {
    const fx = @floor(p.x);
    const fy = @floor(p.y);
    const fz = @floor(p.z);
    const ix: i32 = @intFromFloat(fx);
    const iy: i32 = @intFromFloat(fy);
    const iz: i32 = @intFromFloat(fz);
    const tx = fade(p.x - fx);
    const ty = fade(p.y - fy);
    const tz = fade(p.z - fz);

    const c000 = hash(ix, iy, iz);
    const c100 = hash(ix + 1, iy, iz);
    const c010 = hash(ix, iy + 1, iz);
    const c110 = hash(ix + 1, iy + 1, iz);
    const c001 = hash(ix, iy, iz + 1);
    const c101 = hash(ix + 1, iy, iz + 1);
    const c011 = hash(ix, iy + 1, iz + 1);
    const c111 = hash(ix + 1, iy + 1, iz + 1);

    const x00 = lerp(c000, c100, tx);
    const x10 = lerp(c010, c110, tx);
    const x01 = lerp(c001, c101, tx);
    const x11 = lerp(c011, c111, tx);
    const y0 = lerp(x00, x10, ty);
    const y1 = lerp(x01, x11, ty);
    return lerp(y0, y1, tz);
}

// varias octavas de ruido, resultado en [0, 1]
pub fn fbm(p: Vector3, octaves: u32) f32 {
    var sum: f32 = 0;
    var amp: f32 = 0.5;
    var total: f32 = 0;
    var q = p;
    var i: u32 = 0;
    while (i < octaves) : (i += 1) {
        sum += noise3(q) * amp;
        total += amp;
        amp *= 0.5;
        q = q.scale(2.0);
    }
    return sum / total;
}
