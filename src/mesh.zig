const rl = @import("raylib");
const std = @import("std");
const Mesh = @import("render.zig").Mesh;

// colores de depuración a partir de las normales
pub fn fillNormalColors(normals: []const rl.Vector3, colors: []rl.Vector3) void {
    for (normals, colors) |n, *c| {
        c.* = .{
            .x = n.x * 0.5 + 0.5,
            .y = n.y * 0.5 + 0.5,
            .z = n.z * 0.5 + 0.5,
        };
    }
}

pub fn generateSphere(allocator: std.mem.Allocator, stacks: u32, slices: u32) !Mesh {
    const cols: usize = @as(usize, slices) + 1;
    const vert_count: usize = (@as(usize, stacks) + 1) * cols;

    const positions = try allocator.alloc(rl.Vector3, vert_count);
    errdefer allocator.free(positions);
    const normals = try allocator.alloc(rl.Vector3, vert_count);
    errdefer allocator.free(normals);
    const uvs = try allocator.alloc(rl.Vector2, vert_count);
    errdefer allocator.free(uvs);
    const colors = try allocator.alloc(rl.Vector3, vert_count);
    errdefer allocator.free(colors);

    const stacks_f: f32 = @floatFromInt(stacks);
    const slices_f: f32 = @floatFromInt(slices);

    for (0..@as(usize, stacks) + 1) |i| {
        const v = @as(f32, @floatFromInt(i)) / stacks_f;
        const phi = v * std.math.pi;
        const y = @cos(phi);
        const r = @sin(phi);

        for (0..cols) |j| {
            const u = @as(f32, @floatFromInt(j)) / slices_f;
            const theta = u * std.math.pi * 2;
            const p = rl.Vector3{ .x = r * @sin(theta), .y = y, .z = r * @cos(theta) };
            const k = i * cols + j;
            positions[k] = p;
            normals[k] = p;
            uvs[k] = .{ .x = u, .y = v };
        }
    }
    fillNormalColors(normals, colors);

    // índices
    const tri_count: usize = 2 * @as(usize, stacks) * slices - 2 * @as(usize, slices);
    const indices = try allocator.alloc([3]u32, tri_count);

    var t: usize = 0;
    for (0..stacks) |i| {
        for (0..slices) |j| {
            const a: u32 = @intCast(i * cols + j);
            const b = a + 1;
            const c: u32 = @intCast((i + 1) * cols + j);
            const d = c + 1;

            if (i != stacks - 1) {
                indices[t] = .{ a, c, d };
                t += 1;
            }
            if (i != 0) {
                indices[t] = .{ a, d, b };
                t += 1;
            }
        }
    }

    return .{
        .positions = positions,
        .normals = normals,
        .uvs = uvs,
        .colors = colors,
        .indices = indices,
    };
}
