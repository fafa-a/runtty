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
    var commands = std.ArrayList([]const u8).init(alloc);

    switch (project_type) {
        .zig => {
            try commands.append(try alloc.dupe(u8, "zig build run"));
            try commands.append(try alloc.dupe(u8, "zig build test"));
        },
        .node => {
            // Read package.json for scripts
            const pkg_path = try std.fs.path.join(alloc, &.{ project_path, "package.json" });
            defer alloc.free(pkg_path);

            const content = std.fs.cwd().readFileAlloc(alloc, pkg_path, 1024 * 1024) catch {
                try commands.append(try alloc.dupe(u8, "npm start"));
            };
            defer alloc.free(content);

            // Simple parsing - look for "scripts" section
            if (std.mem.indexOf(u8, content, "\"dev\"") != null) {
                try commands.append(try alloc.dupe(u8, "npm run dev"));
            }
            if (std.mem.indexOf(u8, content, "\"start\"") != null) {
                try commands.append(try alloc.dupe(u8, "npm start"));
            }
            if (std.mem.indexOf(u8, content, "\"build\"") != null) {
                try commands.append(try alloc.dupe(u8, "npm run build"));
            }
        },
        .rust => {
            try commands.append(try alloc.dupe(u8, "cargo run"));
            try commands.append(try alloc.dupe(u8, "cargo test"));
        },
        .go => {
            try commands.append(try alloc.dupe(u8, "go run ."));
            try commands.append(try alloc.dupe(u8, "go test ./..."));
        },
        .python => {
            try commands.append(try alloc.dupe(u8, "python main.py"));
            try commands.append(try alloc.dupe(u8, "python -m pytest"));
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

/// Bind project handlers to WebUI window
pub fn bindProjectHandlers(window: webui) void {
    // project.start handler
    _ = window.bind("project.start", struct {
        fn handler(e: *webui.Event) void {
            _ = e;
            // TODO: Parse project path and command index from event
            std.log.info("Project start requested", .{});
        }
    }.handler) catch |err| {
        std.log.err("Failed to bind project.start: {any}", .{err});
    };

    // project.stop handler
    _ = window.bind("project.stop", struct {
        fn handler(e: *webui.Event) void {
            _ = e;
            // TODO: Parse project path from event
            std.log.info("Project stop requested", .{});
        }
    }.handler) catch |err| {
        std.log.err("Failed to bind project.stop: {any}", .{err});
    };

    std.log.info("Project handlers bound", .{});
}
