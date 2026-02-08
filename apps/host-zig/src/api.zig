const std = @import("std");
const webui = @import("webui");
const FolderApi = @import("folder_api.zig").FolderApi;
const FileDialog = @import("file_dialog.zig");

/// Global allocator for API handlers
var gpa: ?std.heap.GeneralPurposeAllocator(.{}) = null;
var allocator: ?std.mem.Allocator = null;

pub fn getAllocator() std.mem.Allocator {
    if (allocator == null) {
        gpa = std.heap.GeneralPurposeAllocator(.{}){};
        allocator = gpa.?.allocator();
    }
    return allocator.?;
}

/// Event handler: folder.scan
/// Body: { "path": "/home/fafa/workspace" }
/// Response: { "path": "/home/fafa/workspace", "folders": ["a", "b"] }
pub fn handleFolderScan(e: *webui.Event) void {
    const alloc = getAllocator();

    // Get path from event (for now use a default or from JS)
    // TODO: Parse JSON body from event
    const path = "/home/fafa/workspace"; // Placeholder - will be replaced with actual path from JS

    var folders = FolderApi.scanFolders(alloc, path) catch |err| {
        const err_response = FolderApi.buildErrorResponse(alloc, @errorName(err)) catch "{\"error\":\"scan_failed\"}";
        e.returnString(err_response);
        return;
    };
    defer {
        for (folders.items) |name| {
            alloc.free(name);
        }
        folders.deinit(alloc);
    }

    const response = FolderApi.buildResponse(alloc, path, &folders) catch |err| {
        const err_response = FolderApi.buildErrorResponse(alloc, @errorName(err)) catch "{\"error\":\"response_failed\"}";
        e.returnString(err_response);
        return;
    };
    // response is already null-terminated, just free the underlying memory
    defer alloc.free(response.ptr[0..(response.len + 1)]);

    e.returnString(response);
}

/// Event handler: folder.pick
/// Opens native file picker, scans selected folder, returns result
/// Response: { "path": "/home/fafa/workspace", "folders": ["a", "b"] }
pub fn handleFolderPick(e: *webui.Event) void {
    const alloc = getAllocator();

    // Open native folder picker
    const path = FileDialog.pickFolder(alloc) orelse {
        // User cancelled or error
        const err_response = FolderApi.buildErrorResponse(alloc, "user_cancelled") catch "{\"error\":\"user_cancelled\"}";
        e.returnString(err_response);
        return;
    };
    defer alloc.free(path);

    std.log.info("Selected folder: {s}", .{path});

    // Scan subdirectories
    var folders = FolderApi.scanFolders(alloc, path) catch |err| {
        const err_response = FolderApi.buildErrorResponse(alloc, @errorName(err)) catch "{\"error\":\"scan_failed\"}";
        e.returnString(err_response);
        return;
    };
    defer {
        for (folders.items) |name| {
            alloc.free(name);
        }
        folders.deinit(alloc);
    }

    // Build and return response
    const response = FolderApi.buildResponse(alloc, path, &folders) catch |err| {
        const err_response = FolderApi.buildErrorResponse(alloc, @errorName(err)) catch "{\"error\":\"response_failed\"}";
        e.returnString(err_response);
        return;
    };
    defer alloc.free(response.ptr[0..(response.len + 1)]);

    e.returnString(response);
}

/// Bind all handlers to a window
pub fn bindHandlers(window: webui) void {
    _ = window.bind("folder.scan", handleFolderScan) catch |err| {
        std.log.err("Failed to bind folder.scan: {any}", .{err});
    };
    _ = window.bind("folder.pick", handleFolderPick) catch |err| {
        std.log.err("Failed to bind folder.pick: {any}", .{err});
    };
    std.log.info("WebUI handlers bound", .{});
}
