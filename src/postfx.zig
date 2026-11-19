const rl = @import("raylib");
const std = @import("std");
const Framebuffer = @import("framebuffer.zig").Framebuffer;

const samples = 10;
const max_threads = 32;

const Job = struct {
    fb: *Framebuffer,
    src: []const rl.Color,
    amount: f32,
};

fn warpRows(job: *const Job, y0: usize, y1: usize) void {
    const width: usize = @intCast(job.fb.width);
    const height: usize = @intCast(job.fb.height);
    const cx = @as(f32, @floatFromInt(width)) * 0.5;
    const cy = @as(f32, @floatFromInt(height)) * 0.5;
    const strength = job.amount * 0.18;
    const max_x: f32 = @floatFromInt(width - 1);
    const max_y: f32 = @floatFromInt(height - 1);

    for (y0..y1) |y| {
        const fy: f32 = @floatFromInt(y);
        for (0..width) |x| {
            const fx: f32 = @floatFromInt(x);
            const dx = cx - fx;
            const dy = cy - fy;

            var r: u32 = 0;
            var g: u32 = 0;
            var b: u32 = 0;
            for (0..samples) |k| {
                const f = @as(f32, @floatFromInt(k)) / @as(f32, samples - 1) * strength;
                const sx: usize = @intFromFloat(std.math.clamp(fx + dx * f, 0, max_x));
                const sy: usize = @intFromFloat(std.math.clamp(fy + dy * f, 0, max_y));
                const c = job.src[sy * width + sx];
                r += c.r;
                g += c.g;
                b += c.b;
            }

            const tint = job.amount * 40;
            const rf = @as(f32, @floatFromInt(r / samples)) - tint * 0.5;
            const gf = @as(f32, @floatFromInt(g / samples)) + tint * 0.2;
            const bf = @as(f32, @floatFromInt(b / samples)) + tint;
            job.fb.color[y * width + x] = rl.Color.init(
                @intFromFloat(std.math.clamp(rf, 0, 255)),
                @intFromFloat(std.math.clamp(gf, 0, 255)),
                @intFromFloat(std.math.clamp(bf, 0, 255)),
                255,
            );
        }
    }
}

pub const PostFx = struct {
    scratch: []rl.Color,

    pub fn init(allocator: std.mem.Allocator, fb: *const Framebuffer) !PostFx {
        return .{ .scratch = try allocator.alloc(rl.Color, fb.color.len) };
    }

    pub fn deinit(self: *PostFx, allocator: std.mem.Allocator) void {
        allocator.free(self.scratch);
    }

    // efecto de salto a velocidad warp; amount va de 0 a 1
    pub fn warp(self: *PostFx, fb: *Framebuffer, amount: f32, thread_count: usize) void {
        if (amount < 0.01) return;
        @memcpy(self.scratch, fb.color);

        const job = Job{ .fb = fb, .src = self.scratch, .amount = amount };
        const height: usize = @intCast(fb.height);
        const n = std.math.clamp(thread_count, 1, max_threads);
        const rows = (height + n - 1) / n;

        var threads: [max_threads]?std.Thread = @splat(null);
        for (1..n) |t| {
            const y0 = @min(t * rows, height);
            const y1 = @min(y0 + rows, height);
            threads[t] = std.Thread.spawn(.{}, warpRows, .{ &job, y0, y1 }) catch null;
        }

        warpRows(&job, 0, @min(rows, height));

        for (1..n) |t| {
            if (threads[t]) |thread| {
                thread.join();
            } else {
                const y0 = @min(t * rows, height);
                warpRows(&job, y0, @min(y0 + rows, height));
            }
        }
    }
};
