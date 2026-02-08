const std = @import("std");
const webui = @import("webui");

/// HTTP request handler for folder API
/// This is called for both webui events and HTTP requests
pub fn handleFolderApi(allocator: std.mem.Allocator, body: []const u8) ![:0]const u8 {
    _ = body; // For future: parse JSON body for path parameter

    // Open file picker dialog
    const path = try pickFolder(allocator);
    defer allocator.free(path);

    // Scan subdirectories
    var folders = try scanFolders(allocator, path);
    defer {
        for (folders.items) |name| {
            allocator.free(name);
        }
        folders.deinit(allocator);
    }

    // Build JSON response
    return buildJsonResponse(allocator, path, &folders);
}

/// Pick folder using native dialog
fn pickFolder(allocator: std.mem.Allocator) ![]const u8 {
    // Try zenity first
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zenity", "--file-selection", "--directory" },
    }) catch {
        // Fallback to simple input
        return allocator.dupe(u8, "/home/fafa/workspace");
    };

    if (result.term != .Exited or result.term.Exited != 0) {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
        return error.DialogCancelled;
    }

    const path = std.mem.trimRight(u8, result.stdout, "\n");
    const duped = try allocator.dupe(u8, path);
    allocator.free(result.stdout);
    allocator.free(result.stderr);
    return duped;
}

/// Scan subdirectories (level 1 only)
fn scanFolders(allocator: std.mem.Allocator, path: []const u8) !std.ArrayList([]const u8) {
    var folders: std.ArrayList([]const u8) = .empty;

    var dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind == .directory) {
            const name = try allocator.dupe(u8, entry.name);
            try folders.append(allocator, name);
        }
    }

    // Sort
    std.mem.sort([]const u8, folders.items, {}, struct {
        pub fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    return folders;
}

/// Build JSON response
fn buildJsonResponse(
    allocator: std.mem.Allocator,
    path: []const u8,
    folders: *const std.ArrayList([]const u8),
) ![:0]const u8 {
    var json: std.ArrayList(u8) = .empty;
    defer json.deinit(allocator);

    const writer = json.writer(allocator);
    try writer.writeAll("{\"path\":\"");
    try writeEscapedString(writer, path);
    try writer.writeAll("\",\"folders\":[");

    for (folders.items, 0..) |name, i| {
        if (i > 0) try writer.writeByte(',');
        try writer.writeByte('"');
        try writeEscapedString(writer, name);
        try writer.writeByte('"');
    }

    try writer.writeAll("]}");
    try writer.writeByte(0);

    const slice = try json.toOwnedSlice(allocator);
    return slice[0 .. slice.len - 1 :0];
}

/// Escape string for JSON
fn writeEscapedString(writer: anytype, str: []const u8) !void {
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
}
