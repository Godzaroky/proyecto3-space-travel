// Generado con asistencia de IA (Claude)
const rl = @import("raylib");
const std = @import("std");
const Mat4 = @import("math.zig").Mat4;

const Vector3 = rl.Vector3;

const world_up = Vector3{ .x = 0, .y = 1, .z = 0 };
const pitch_limit = std.math.degreesToRadians(89.0);

pub const Camera = struct {
    position: Vector3,
    yaw: f32 = 0,
    pitch: f32 = 0,
    fov_y: f32 = std.math.degreesToRadians(60.0),
    near: f32 = 0.1,
    far: f32 = 200.0,
    move_speed: f32 = 6.0,
    boost_multiplier: f32 = 4.0,
    mouse_sensitivity: f32 = 0.0025,
    mouse_captured: bool = true,

    pub fn forward(self: Camera) Vector3 {
        const cp = @cos(self.pitch);
        return .{
            .x = cp * @sin(self.yaw),
            .y = @sin(self.pitch),
            .z = -cp * @cos(self.yaw),
        };
    }

    pub fn right(self: Camera) Vector3 {
        return .{ .x = @cos(self.yaw), .y = 0, .z = @sin(self.yaw) };
    }

    pub fn view(self: Camera) Mat4 {
        return Mat4.lookAt(self.position, self.position.add(self.forward()), world_up);
    }

    pub fn projection(self: Camera, aspect: f32) Mat4 {
        return Mat4.perspective(self.fov_y, aspect, self.near, self.far);
    }

    pub fn captureMouse(self: *Camera, captured: bool) void {
        self.mouse_captured = captured;
        if (captured) {
            rl.hideCursor();
            centerMouse();
        } else {
            rl.showCursor();
        }
    }

    pub fn update(self: *Camera, dt: f32) void {
        if (rl.isKeyPressed(.tab)) self.captureMouse(!self.mouse_captured);

        if (self.mouse_captured and rl.isWindowFocused()) {
            const center = screenCenter();
            const mouse = rl.getMousePosition();
            self.yaw += (mouse.x - center.x) * self.mouse_sensitivity;
            self.pitch -= (mouse.y - center.y) * self.mouse_sensitivity;
            self.pitch = std.math.clamp(self.pitch, -pitch_limit, pitch_limit);
            centerMouse();
        }

        var dir = Vector3.zero();
        const f = self.forward();
        const r = self.right();
        if (rl.isKeyDown(.w)) dir = dir.add(f);
        if (rl.isKeyDown(.s)) dir = dir.subtract(f);
        if (rl.isKeyDown(.d)) dir = dir.add(r);
        if (rl.isKeyDown(.a)) dir = dir.subtract(r);
        if (rl.isKeyDown(.space)) dir = dir.add(world_up);
        if (rl.isKeyDown(.left_control)) dir = dir.subtract(world_up);

        if (dir.lengthSqr() > 0) {
            var speed = self.move_speed;
            if (rl.isKeyDown(.left_shift)) speed *= self.boost_multiplier;
            self.position = self.position.add(dir.normalize().scale(speed * dt));
        }
    }
};

fn screenCenter() rl.Vector2 {
    return .{
        .x = @as(f32, @floatFromInt(rl.getScreenWidth())) * 0.5,
        .y = @as(f32, @floatFromInt(rl.getScreenHeight())) * 0.5,
    };
}

fn centerMouse() void {
    rl.setMousePosition(@divTrunc(rl.getScreenWidth(), 2), @divTrunc(rl.getScreenHeight(), 2));
}
