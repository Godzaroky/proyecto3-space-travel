const rl = @import("raylib");
const std = @import("std");
const SolarSystem = @import("solar_system.zig").SolarSystem;
const Camera = @import("camera.zig").Camera;

const Vector3 = rl.Vector3;

// FOV extra en el punto más rápido del viaje
const warp_fov = std.math.degreesToRadians(35.0);
const pitch_limit = std.math.degreesToRadians(89.0);

fn easeInOut(t: f32) f32 {
    return if (t < 0.5) 4 * t * t * t else 1 - std.math.pow(f32, -2 * t + 2, 3) / 2;
}

fn smoothstep(e0: f32, e1: f32, x: f32) f32 {
    const t = std.math.clamp((x - e0) / (e1 - e0), 0, 1);
    return t * t * (3 - 2 * t);
}

// diferencia de ángulos en [-pi, pi]
fn angleDiff(a: f32, b: f32) f32 {
    const two_pi = std.math.pi * 2.0;
    const d = a - b;
    return d - two_pi * @floor((d + std.math.pi) / two_pi);
}

pub const Travel = struct {
    active: bool = false,
    target: usize = 0,
    t: f32 = 0,
    duration: f32 = 2.5,
    arc_height: f32 = 0,
    start_pos: Vector3 = .{ .x = 0, .y = 0, .z = 0 },
    start_yaw: f32 = 0,
    start_pitch: f32 = 0,
    base_fov: f32 = 0,

    fn destination(system: *const SolarSystem, target: usize) Vector3 {
        const body = system.bodies[target];
        const dist = body.radius * 4 + 9;

        var dir = system.sunPosition().subtract(body.position);
        if (dir.length() < 0.001) dir = .{ .x = 0, .y = 0, .z = 1 };
        dir = dir.normalize().add(.{ .x = 0, .y = 0.35, .z = 0 }).normalize();
        return body.position.add(dir.scale(dist));
    }

    pub fn start(self: *Travel, camera: *const Camera, system: *const SolarSystem, target: usize) void {
        if (self.active) return;

        const dest = destination(system, target);
        const dist = camera.position.distance(dest);

        self.* = .{
            .active = true,
            .target = target,
            .t = 0,
            .duration = std.math.clamp(1.5 + dist / 40, 1.5, 4.0),
            .arc_height = @min(dist * 0.15, 30),
            .start_pos = camera.position,
            .start_yaw = camera.yaw,
            .start_pitch = camera.pitch,
            .base_fov = camera.fov_y,
        };
    }

    // intensidad del efecto, de 0 a 1
    pub fn warp(self: *const Travel) f32 {
        if (!self.active) return 0;
        return @sin(std.math.pi * std.math.clamp(self.t, 0, 1));
    }

    pub fn update(self: *Travel, camera: *Camera, system: *const SolarSystem, dt: f32) void {
        if (!self.active) return;

        self.t = @min(self.t + dt / self.duration, 1);
        const e = easeInOut(self.t);

        // posición: curva sobre el plano de las órbitas hacia el destino, que se mueve
        const dest = destination(system, self.target);
        const lift = @sin(std.math.pi * e) * self.arc_height;
        camera.position = self.start_pos.lerp(dest, e).add(.{ .x = 0, .y = lift, .z = 0 });

        // orientación: gira hacia el cuerpo al inicio del viaje
        const look = system.bodies[self.target].position.subtract(camera.position);
        const len = look.length();
        if (len > 0.001) {
            const target_yaw = std.math.atan2(look.x, -look.z);
            const target_pitch = std.math.clamp(std.math.asin(std.math.clamp(look.y / len, -1, 1)), -pitch_limit, pitch_limit);
            const k = smoothstep(0, 0.35, self.t);
            camera.yaw = self.start_yaw + angleDiff(target_yaw, self.start_yaw) * k;
            camera.pitch = self.start_pitch + (target_pitch - self.start_pitch) * k;
        }

        camera.fov_y = self.base_fov + warp_fov * self.warp();

        if (self.t >= 1) {
            self.active = false;
            camera.fov_y = self.base_fov;
            camera.captureMouse(camera.mouse_captured);
        }
    }
};
