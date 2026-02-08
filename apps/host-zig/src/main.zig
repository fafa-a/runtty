const std = @import("std");
const webui = @import("webui");
const api = @import("api.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    std.log.info("RunTTY Host starting...", .{});
    defer std.log.info("RunTTY Host exiting...", .{});

    const cwd = try std.fs.cwd().realpathAlloc(alloc, ".");
    defer alloc.free(cwd);
    std.log.info("CWD: {s}", .{cwd});

    const window = webui.newWindow();
    api.bindApi(window);

    // Serve UI on all interfaces so external browser can connect
    window.setPublic(true);

    const ui_path = "../ui/dist";
    std.fs.cwd().access(ui_path, .{}) catch |e| {
        std.log.err("Cannot access {s}: {any}", .{ ui_path, e });
        return e;
    };

    const raw_url = try window.startServer(ui_path);
    // Convert 192.168.x.x to 127.0.0.1 for local browser
    const localhost_url = try std.mem.replaceOwned(u8, alloc, raw_url, "192.168.1.18", "127.0.0.1");
    defer alloc.free(localhost_url);
    // Convert to null-terminated string
    const url = try alloc.dupeZ(u8, localhost_url);
    defer alloc.free(url);
    std.log.info("UI available at: {s}", .{url});

    // Open Firefox (WebView doesn't work in this environment)
    std.log.info("Opening Firefox...", .{});

    const result = std.process.Child.run(.{
        .allocator = alloc,
        .argv = &.{ "firefox", url },
    }) catch |e| {
        std.log.err("Failed to launch Firefox: {any}", .{e});
        std.log.info("Please open this URL manually: {s}", .{url});
        webui.wait();
        return;
    };

    if (result.term != .Exited or result.term.Exited != 0) {
        std.log.warn("Firefox exit code: {any}", .{result.term});
    } else {
        std.log.info("Firefox opened", .{});
    }

    // Wait for connections
    webui.wait();
}
