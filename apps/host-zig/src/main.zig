const std = @import("std");
const webui = @import("webui");
const handlers = @import("rpc.zig");
const projects = @import("project_runner.zig");

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
    handlers.bindHandlers(window);
    projects.bindProjectHandlers(window);

    // Set fixed port 3210 for HTTP API and UI
    window.setPort(3210) catch |e| {
        std.log.err("Failed to set port 3210: {any}", .{e});
        return e;
    };

    // Serve UI on all interfaces so external browser can connect
    window.setPublic(true);

    const ui_path = "../ui/dist";
    std.fs.cwd().access(ui_path, .{}) catch |e| {
        std.log.err("Cannot access {s}: {any}", .{ ui_path, e });
        return e;
    };

    _ = try window.startServer(ui_path);
    const url = "http://127.0.0.1:3210";
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
