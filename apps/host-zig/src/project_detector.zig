const std = @import("std");

/// Project type detection based on configuration files
pub const ProjectType = enum {
    zig, // build.zig or build.zig.zon
    node, // package.json
    rust, // Cargo.toml
    go, // go.mod
    python, // pyproject.toml, setup.py, requirements.txt
    unknown,
};

pub const ProjectInfo = struct {
    name: []const u8,
    project_type: ProjectType,
    config_file: ?[]const u8,
};

/// Configuration files that identify project types
const CONFIG_FILES = .{
    .{ "build.zig", ProjectType.zig },
    .{ "build.zig.zon", ProjectType.zig },
    .{ "package.json", ProjectType.node },
    .{ "Cargo.toml", ProjectType.rust },
    .{ "go.mod", ProjectType.go },
    .{ "pyproject.toml", ProjectType.python },
    .{ "setup.py", ProjectType.python },
    .{ "requirements.txt", ProjectType.python },
    .{ "Pipfile", ProjectType.python },
};

/// Detect project type by scanning for config files
pub fn detectProject(allocator: std.mem.Allocator, folder_path: []const u8) !ProjectInfo {
    // Extract folder name as default project name
    const basename = std.fs.path.basename(folder_path);
    const name = try allocator.dupe(u8, basename);

    var project_type: ProjectType = .unknown;
    var config_file: ?[]const u8 = null;

    // Open folder and look for config files
    var dir = std.fs.openDirAbsolute(folder_path, .{ .iterate = true }) catch |e| {
        allocator.free(name);
        return e;
    };
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        // Check each known config file
        inline for (CONFIG_FILES) |cfg| {
            if (std.mem.eql(u8, entry.name, cfg[0])) {
                project_type = cfg[1];
                config_file = try allocator.dupe(u8, entry.name);
                break;
            }
        }

        if (config_file != null) break; // Found one, stop searching
    }

    return ProjectInfo{
        .name = name,
        .project_type = project_type,
        .config_file = config_file,
    };
}

/// Free project info memory
pub fn freeProjectInfo(allocator: std.mem.Allocator, info: *ProjectInfo) void {
    allocator.free(info.name);
    if (info.config_file) |cfg| {
        allocator.free(cfg);
    }
}

/// Get project type as string
pub fn projectTypeString(project_type: ProjectType) []const u8 {
    return switch (project_type) {
        .zig => "zig",
        .node => "node",
        .rust => "rust",
        .go => "go",
        .python => "python",
        .unknown => "unknown",
    };
}
