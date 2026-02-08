const std = @import("std");
const webui = @import("webui");

/// Escape a string for JSON (basic escaping for folder names)
fn escapeJson(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    const writer = result.writer(allocator);

    for (str) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }

    return result.toOwnedSlice(allocator);
}

pub const FolderApi = struct {
    const Self = @This();

    /// Scan immediate subdirectories only (non-recursive, fast)
    pub fn scanFolders(allocator: std.mem.Allocator, path: []const u8) !std.ArrayList([]const u8) {
        var folders: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (folders.items) |name| {
                allocator.free(name);
            }
            folders.deinit(allocator);
        }

        var dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch |e| {
            std.log.err("Failed to open directory {s}: {any}", .{ path, e });
            return e;
        };
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind == .directory) {
                const name_copy = try allocator.dupe(u8, entry.name);
                try folders.append(allocator, name_copy);
            }
        }

        // Sort folder names alphabetically
        std.mem.sort([]const u8, folders.items, {}, struct {
            pub fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.order(u8, a, b) == .lt;
            }
        }.lessThan);

        return folders;
    }

    /// Build JSON response: { "path": "/home/x", "folders": ["a", "b"] }
    /// Returns null-terminated string for webui compatibility
    pub fn buildResponse(allocator: std.mem.Allocator, path: []const u8, folders: *const std.ArrayList([]const u8)) ![:0]const u8 {
        var json: std.ArrayList(u8) = .empty;
        errdefer json.deinit(allocator);

        const writer = json.writer(allocator);

        const escaped_path = try escapeJson(allocator, path);
        defer allocator.free(escaped_path);

        try writer.writeAll("{\"path\":\"");
        try writer.writeAll(escaped_path);
        try writer.writeAll("\",\"folders\":[");

        for (folders.items, 0..) |name, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.writeByte('"');
            const escaped_name = try escapeJson(allocator, name);
            defer allocator.free(escaped_name);
            try writer.writeAll(escaped_name);
            try writer.writeByte('"');
        }

        try writer.writeAll("]}");
        try writer.writeByte(0); // Null terminator

        const slice = try json.toOwnedSlice(allocator);
        // Convert to sentinel-terminated slice
        return slice[0..(slice.len - 1) :0];
    }

    /// Build error JSON response
    /// Returns null-terminated string for webui compatibility
    pub fn buildErrorResponse(allocator: std.mem.Allocator, error_msg: []const u8) ![:0]const u8 {
        var json: std.ArrayList(u8) = .empty;
        errdefer json.deinit(allocator);

        const writer = json.writer(allocator);

        const escaped = try escapeJson(allocator, error_msg);
        defer allocator.free(escaped);

        try writer.writeAll("{\"error\":\"");
        try writer.writeAll(escaped);
        try writer.writeAll("}");
        try writer.writeByte(0); // Null terminator

        const slice = try json.toOwnedSlice(allocator);
        // Convert to sentinel-terminated slice
        return slice[0..(slice.len - 1) :0];
    }
};
