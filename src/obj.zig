const std = @import("std");
const rl = @import("raylib");
const Mesh = @import("render.zig").Mesh;
const mesh = @import("mesh.zig");

const FaceKey = struct {
    p: i32,
    t: i32,
    n: i32,
};

fn resolveIndex(i: i32, count: usize) !i32 {
    const c: i32 = @intCast(count);
    const idx = if (i > 0) i - 1 else if (i < 0) c + i else return error.InvalidIndex;
    if (idx < 0 or idx >= c) return error.InvalidIndex;
    return idx;
}

fn parseOptionalIndex(part: ?[]const u8, count: usize) !i32 {
    const s = part orelse return -1;
    if (s.len == 0) return -1;
    return resolveIndex(try std.fmt.parseInt(i32, s, 10), count);
}

fn parseFaceVertex(token: []const u8, n_pos: usize, n_uv: usize, n_norm: usize) !FaceKey {
    var parts = std.mem.splitScalar(u8, token, '/');

    const p_str = parts.next() orelse return error.InvalidFace;
    const p = try resolveIndex(try std.fmt.parseInt(i32, p_str, 10), n_pos);
    const t = try parseOptionalIndex(parts.next(), n_uv);
    const n = try parseOptionalIndex(parts.next(), n_norm);

    return .{ .p = p, .t = t, .n = n };
}

fn nextFloat(tokens: anytype) !f32 {
    const tok = tokens.next() orelse return error.InvalidObj;
    return std.fmt.parseFloat(f32, tok);
}

fn computeNormals(positions: []const rl.Vector3, indices: []const [3]u32, normals: []rl.Vector3) void {
    @memset(normals, rl.Vector3.zero());
    for (indices) |tri| {
        const p0 = positions[tri[0]];
        const p1 = positions[tri[1]];
        const p2 = positions[tri[2]];
        const n = p1.subtract(p0).crossProduct(p2.subtract(p0));
        for (tri) |i| {
            normals[i] = normals[i].add(n);
        }
    }
    for (normals) |*n| {
        n.* = n.normalize();
    }
}

pub fn loadObj(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Mesh {
    const data = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(64 * 1024 * 1024));
    defer allocator.free(data);

    var obj_pos: std.ArrayList(rl.Vector3) = .empty;
    defer obj_pos.deinit(allocator);
    var obj_uv: std.ArrayList(rl.Vector2) = .empty;
    defer obj_uv.deinit(allocator);
    var obj_norm: std.ArrayList(rl.Vector3) = .empty;
    defer obj_norm.deinit(allocator);

    var positions: std.ArrayList(rl.Vector3) = .empty;
    defer positions.deinit(allocator);
    var uvs: std.ArrayList(rl.Vector2) = .empty;
    defer uvs.deinit(allocator);
    var normals: std.ArrayList(rl.Vector3) = .empty;
    defer normals.deinit(allocator);
    var indices: std.ArrayList([3]u32) = .empty;
    defer indices.deinit(allocator);

    var map = std.AutoHashMap(FaceKey, u32).init(allocator);
    defer map.deinit();
    var face: std.ArrayList(u32) = .empty;
    defer face.deinit(allocator);

    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        var tokens = std.mem.tokenizeAny(u8, line, " \t");
        const tag = tokens.next() orelse continue;

        if (std.mem.eql(u8, tag, "v")) {
            const x = try nextFloat(&tokens);
            const y = try nextFloat(&tokens);
            const z = try nextFloat(&tokens);
            try obj_pos.append(allocator, .{ .x = x, .y = y, .z = z });
        } else if (std.mem.eql(u8, tag, "vt")) {
            const u = try nextFloat(&tokens);
            const v = try nextFloat(&tokens);
            try obj_uv.append(allocator, .{ .x = u, .y = 1.0 - v });
        } else if (std.mem.eql(u8, tag, "vn")) {
            const x = try nextFloat(&tokens);
            const y = try nextFloat(&tokens);
            const z = try nextFloat(&tokens);
            try obj_norm.append(allocator, .{ .x = x, .y = y, .z = z });
        } else if (std.mem.eql(u8, tag, "f")) {
            face.clearRetainingCapacity();

            while (tokens.next()) |token| {
                const key = try parseFaceVertex(token, obj_pos.items.len, obj_uv.items.len, obj_norm.items.len);
                const entry = try map.getOrPut(key);
                if (!entry.found_existing) {
                    try positions.append(allocator, obj_pos.items[@intCast(key.p)]);
                    try uvs.append(allocator, if (key.t >= 0) obj_uv.items[@intCast(key.t)] else rl.Vector2.zero());
                    try normals.append(allocator, if (key.n >= 0) obj_norm.items[@intCast(key.n)] else rl.Vector3.zero());
                    entry.value_ptr.* = @intCast(positions.items.len - 1);
                }
                try face.append(allocator, entry.value_ptr.*);
            }

            if (face.items.len < 3) return error.InvalidFace;

            for (1..face.items.len - 1) |k| {
                try indices.append(allocator, .{ face.items[0], face.items[k], face.items[k + 1] });
            }
        }
    }

    if (obj_norm.items.len == 0) {
        computeNormals(positions.items, indices.items, normals.items);
    }

    const colors = try allocator.alloc(rl.Vector3, positions.items.len);
    errdefer allocator.free(colors);
    mesh.fillNormalColors(normals.items, colors);

    const out_positions = try positions.toOwnedSlice(allocator);
    errdefer allocator.free(out_positions);
    const out_normals = try normals.toOwnedSlice(allocator);
    errdefer allocator.free(out_normals);
    const out_uvs = try uvs.toOwnedSlice(allocator);
    errdefer allocator.free(out_uvs);
    const out_indices = try indices.toOwnedSlice(allocator);

    return .{
        .positions = out_positions,
        .normals = out_normals,
        .uvs = out_uvs,
        .colors = colors,
        .indices = out_indices,
    };
}
