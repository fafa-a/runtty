const std = @import("std");
const webui = @import("webui");

const ProjectType = enum {
    zig,
    node,
    rust,
    go,
    python,
    unknown,
};

const ProjectInfo = struct {
    name: []const u8,
    project_type: ProjectType,
    config_file: ?[]const u8,
    commands: std.ArrayList([]const u8),
    process: ?std.process.Child = null,
};

var gpa: ?std.heap.GeneralPurposeAllocator(.{}) = null;
var allocator: ?std.mem.Allocator = null;
var active_projects: ?std.StringHashMap(*ProjectInfo) = null;

fn getAlloc() std.mem.Allocator {
    if (allocator == null) {
        gpa = std.heap.GeneralPurposeAllocator(.{}){};
        allocator = gpa.?.allocator();
    }
    return allocator.?;
}

fn getProjects() !*std.StringHashMap(*ProjectInfo) {
    if (active_projects == null) {
        active_projects = std.StringHashMap(*ProjectInfo).init(getAlloc());
    }
    return &active_projects.?;
}

/// Detect project type and available commands
pub fn detectProject(project_path: []const u8) !?ProjectInfo {
    const alloc = getAlloc();

    // Check for config files
    const files = .{
        .{ "package.json", ProjectType.node },
        .{ "build.zig", ProjectType.zig },
        .{ "Cargo.toml", ProjectType.rust },
        .{ "go.mod", ProjectType.go },
        .{ "pyproject.toml", ProjectType.python },
        .{ "setup.py", ProjectType.python },
    };

    var dir = try std.fs.openDirAbsolute(project_path, .{ .iterate = true });
    defer dir.close();

    var project_type: ProjectType = .unknown;
    var config_file: ?[]const u8 = null;

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        inline for (files) |file| {
            if (std.mem.eql(u8, entry.name, file[0])) {
                project_type = file[1];
                config_file = try alloc.dupe(u8, entry.name);
            }
        }
    }

    if (project_type == .unknown) return null;

    // Get commands based on type
    var commands: std.ArrayList([]const u8) = .empty;

    switch (project_type) {
        .zig => {
            try commands.append(alloc, try alloc.dupe(u8, "zig build run"));
            try commands.append(alloc, try alloc.dupe(u8, "zig build test"));
        },
        .node => blk: {
            // Read package.json for scripts
            const pkg_path = try std.fs.path.join(alloc, &.{ project_path, "package.json" });
            defer alloc.free(pkg_path);

            const content = std.fs.cwd().readFileAlloc(alloc, pkg_path, 1024 * 1024) catch {
                try commands.append(alloc, try alloc.dupe(u8, "npm start"));
                break :blk;
            };
            defer alloc.free(content);

            // Simple parsing - look for "scripts" section
            if (std.mem.indexOf(u8, content, "\"dev\"") != null) {
                try commands.append(alloc, try alloc.dupe(u8, "npm run dev"));
            }
            if (std.mem.indexOf(u8, content, "\"start\"") != null) {
                try commands.append(alloc, try alloc.dupe(u8, "npm start"));
            }
            if (std.mem.indexOf(u8, content, "\"build\"") != null) {
                try commands.append(alloc, try alloc.dupe(u8, "npm run build"));
            }
        },
        .rust => {
            try commands.append(alloc, try alloc.dupe(u8, "cargo run"));
            try commands.append(alloc, try alloc.dupe(u8, "cargo test"));
        },
        .go => {
            try commands.append(alloc, try alloc.dupe(u8, "go run ."));
            try commands.append(alloc, try alloc.dupe(u8, "go test ./..."));
        },
        .python => {
            try commands.append(alloc, try alloc.dupe(u8, "python main.py"));
            try commands.append(alloc, try alloc.dupe(u8, "python -m pytest"));
        },
        else => {},
    }

    const name = try alloc.dupe(u8, std.fs.path.basename(project_path));

    return ProjectInfo{
        .name = name,
        .project_type = project_type,
        .config_file = config_file,
        .commands = commands,
        .process = null,
    };
}

/// Start project process
pub fn startProject(project_path: []const u8, command_index: usize, window: webui) !void {
    const alloc = getAlloc();

    // Detect project
    const info_opt = try detectProject(project_path);
    if (info_opt == null) {
        std.log.err("No project found at {s}", .{project_path});
        return error.ProjectNotFound;
    }

    const info = info_opt.?;

    if (command_index >= info.commands.items.len) {
        std.log.err("Invalid command index", .{});
        return error.InvalidCommand;
    }

    const cmd = info.commands.items[command_index];
    std.log.info("Starting project with: {s}", .{cmd});

    // Parse command
    var argv = std.ArrayList([]const u8).init(alloc);
    defer argv.deinit();

    var it = std.mem.splitScalar(u8, cmd, ' ');
    while (it.next()) |arg| {
        if (arg.len > 0) {
            try argv.append(arg);
        }
    }

    if (argv.items.len == 0) {
        return error.EmptyCommand;
    }

    // Start process
    var child = std.process.Child.init(argv.items, alloc);
    child.cwd = project_path;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Store process
    const projects = try getProjects();
    const key = try alloc.dupe(u8, project_path);

    var stored_info = try alloc.create(ProjectInfo);
    stored_info.* = info;
    stored_info.process = child;

    try projects.put(key, stored_info);

    std.log.info("Project started with PID: {any}", .{child.id});

    // Send status to UI
    const status_msg = try std.fmt.allocPrintZ(alloc, "{{\"status\":\"running\",\"project\":\"{s}\",\"command\":\"{s}\"}}", .{ info.name, cmd });
    defer alloc.free(status_msg);
    window.send("project.status", status_msg);

    // TODO: Spawn thread to read logs and send to UI
}

/// Stop project process
pub fn stopProject(project_path: []const u8, window: webui) !void {
    const alloc = getAlloc();
    const projects = try getProjects();

    const entry = projects.get(project_path) orelse {
        std.log.warn("Project not running: {s}", .{project_path});
        return;
    };

    if (entry.process) |*proc| {
        _ = proc.kill() catch |e| {
            std.log.err("Failed to kill process: {any}", .{e});
        };
        std.log.info("Project stopped: {s}", .{entry.name});
    }

    // Send status to UI
    const status_msg = try std.fmt.allocPrintZ(alloc, "{{\"status\":\"stopped\",\"project\":\"{s}\"}}", .{entry.name});
    defer alloc.free(status_msg);
    window.send("project.status", status_msg);

    // Cleanup
    if (projects.remove(project_path)) {
        // TODO: Free memory properly
    }
}

/// Parse simple JSON to extract path and command
fn parseStartJson(data: []const u8) ?struct { path: []const u8, command: usize } {
    // Simple parsing: look for "path":"..." and "command":N
    const path_prefix = "\"path\":\"";
    const cmd_prefix = "\"command\":";

    var path_start = std.mem.indexOf(u8, data, path_prefix) orelse return null;
    path_start += path_prefix.len;
    const path_end = std.mem.indexOf(u8, data[path_start..], "\"") orelse return null;
    const path = data[path_start .. path_start + path_end];

    var cmd_start = std.mem.indexOf(u8, data, cmd_prefix) orelse return null;
    cmd_start += cmd_prefix.len;
    const cmd_end = std.mem.indexOfAny(u8, data[cmd_start..], ",}") orelse data.len - cmd_start;
    const cmd_str = data[cmd_start .. cmd_start + cmd_end];
    const command = std.fmt.parseInt(usize, cmd_str, 10) catch 0;

    return .{ .path = path, .command = command };
}

/// Parse simple JSON to extract path
fn parseStopJson(data: []const u8) ?[]const u8 {
    const path_prefix = "\"path\":\"";
    var path_start = std.mem.indexOf(u8, data, path_prefix) orelse return null;
    path_start += path_prefix.len;
    const path_end = std.mem.indexOf(u8, data[path_start..], "\"") orelse return null;
    return data[path_start .. path_start + path_end];
}

/// Store window reference for callbacks
var g_window: ?webui = null;

/// Bind project handlers to WebUI window
pub fn bindProjectHandlers(window: webui) void {
    g_window = window;

    // project.start handler
    _ = window.bind("project.start", struct {
        fn handler(e: *webui.Event) void {
            const data = e.getString();

            if (parseStartJson(data)) |parsed| {
                std.log.info("Starting project in folder: {s}, command index: {d}", .{ parsed.path, parsed.command });

                // Actually start the project
                startProjectHandler(parsed.path, parsed.command, e) catch |err| {
                    std.log.err("Failed to start project: {any}", .{err});
                    e.returnString("{\"error\":\"start_failed\"}");
                };
            } else {
                std.log.err("Failed to parse project.start data: {s}", .{data});
                e.returnString("{\"error\":\"parse_failed\"}");
            }
        }
    }.handler) catch |err| {
        std.log.err("Failed to bind project.start: {any}", .{err});
    };

    // project.stop handler
    _ = window.bind("project.stop", struct {
        fn handler(e: *webui.Event) void {
            const data = e.getString();

            if (parseStopJson(data)) |path| {
                std.log.info("Stopping project in folder: {s}", .{path});

                // Actually stop the project
                stopProjectHandler(path, e) catch |err| {
                    std.log.err("Failed to stop project: {any}", .{err});
                    e.returnString("{\"error\":\"stop_failed\"}");
                };
            } else {
                std.log.err("Failed to parse project.stop data: {s}", .{data});
                e.returnString("{\"error\":\"parse_failed\"}");
            }
        }
    }.handler) catch |err| {
        std.log.err("Failed to bind project.stop: {any}", .{err});
    };

    std.log.info("Project handlers bound", .{});
}

/// Helper to format string with null terminator
fn formatZ(alloc: std.mem.Allocator, comptime fmt: []const u8, args: anytype) ![:0]const u8 {
    const str = try std.fmt.allocPrint(alloc, fmt, args);
    defer alloc.free(str);
    const result = try alloc.allocSentinel(u8, str.len, 0);
    @memcpy(result, str);
    return result;
}

/// Start project handler - detects type and runs command
fn startProjectHandler(project_path: []const u8, command_index: usize, e: *webui.Event) !void {
    const alloc = getAlloc();

    // Detect project
    const info_opt = try detectProject(project_path);
    if (info_opt == null) {
        return error.ProjectNotFound;
    }

    const info = info_opt.?;

    if (command_index >= info.commands.items.len) {
        return error.InvalidCommand;
    }

    const cmd = info.commands.items[command_index];
    std.log.info("Command to run: {s}", .{cmd});

    // Return success with command info
    const response = try formatZ(alloc, "{{\"status\":\"started\",\"project\":\"{s}\",\"command\":\"{s}\"}}", .{ info.name, cmd });
    defer alloc.free(response);
    e.returnString(response);

    // TODO: Actually spawn the process and capture output
    std.log.info("Project {s} would run: {s}", .{ info.name, cmd });
}

/// Stop project handler
fn stopProjectHandler(project_path: []const u8, e: *webui.Event) !void {
    const alloc = getAlloc();

    // For now just acknowledge
    const response = try formatZ(alloc, "{{\"status\":\"stopped\",\"path\":\"{s}\"}}", .{project_path});
    defer alloc.free(response);
    e.returnString(response);

    std.log.info("Project at {s} would be stopped", .{project_path});
}
