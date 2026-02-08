const std = @import("std");
const webui = @import("webui");
const api = @import("api.zig");

pub fn main() !void {
    std.log.info("RunTTY Host starting...", .{});
    defer std.log.info("RunTTY Host exiting...", .{});

    // Initialize WebUI window
    const window = webui.newWindow();

    // Bind API endpoints
    api.bindApi(window);

    // Serve the UI from the dist folder
    const ui_path = "../ui/dist";
    const url = try window.startServer(ui_path);
    std.log.info("UI served at: {s}", .{url});

    // Show in Firefox (most reliable on Linux)
    // Force Firefox to avoid WebView issues
    std.log.info("Opening Firefox...", .{});
    try window.showBrowser(url, .Firefox);
    std.log.info("Firefox opened", .{});

    // Wait until the window is closed
    webui.wait();
}
