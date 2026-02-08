const std = @import("std");
const webui = @import("webui");
const api = @import("api.zig");

fn toLocalhostUrl(allocator: std.mem.Allocator, url: [:0]const u8) ![:0]const u8 {
    // Remplace "0.0.0.0" par "127.0.0.1" pour le client
    const replaced = try std.mem.replaceOwned(u8, allocator, url, "0.0.0.0", "127.0.0.1");
    // Convertir en [:0]const u8 (null-terminated)
    const result = try allocator.allocSentinel(u8, replaced.len, 0);
    @memcpy(result, replaced);
    allocator.free(replaced);
    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    std.log.info("RunTTY Host starting...", .{});
    defer std.log.info("RunTTY Host exiting...", .{});

    // Check current directory
    const cwd = try std.fs.cwd().realpathAlloc(alloc, ".");
    defer alloc.free(cwd);
    std.log.info("CWD: {s}", .{cwd});

    // Initialize WebUI window
    const window = webui.newWindow();

    // Bind API endpoints
    api.bindApi(window);

    // Allow public access (écoute sur 0.0.0.0)
    window.setPublic(true);

    // Serve the UI from the dist folder
    const ui_path = "../ui/dist";

    // Check if path exists
    std.fs.cwd().access(ui_path, .{}) catch |e| {
        std.log.err("Cannot access {s}: {any}", .{ ui_path, e });
        return e;
    };

    const raw_url = try window.startServer(ui_path);
    std.log.info("Raw URL: {s}", .{raw_url});

    // Convert to localhost URL for client
    const url = try toLocalhostUrl(alloc, raw_url);
    defer alloc.free(url);
    std.log.info("Client URL: {s}", .{url});

    // Open in system browser (firefox/chrome/etc)
    // Use showBrowser with Firefox for external browser mode
    std.log.info("Opening browser...", .{});
    try window.showBrowser(url, .Firefox);
    std.log.info("Browser opened", .{});

    // Wait until the window is closed
    webui.wait();
}
