const std = @import("std");
const webui = @import("webui");

/// Opens a native folder picker dialog
/// Returns the selected folder path, or null if cancelled/error
pub fn pickFolder(allocator: std.mem.Allocator) ?[]const u8 {
    // Platform-specific folder picker
    const path = switch (@import("builtin").os.tag) {
        .linux => pickFolderLinux(allocator),
        .windows => pickFolderWindows(allocator),
        .macos => pickFolderMac(allocator),
        else => {
            std.log.err("Folder picker not implemented for this platform", .{});
            return null;
        },
    } catch |err| {
        std.log.err("Failed to open folder picker: {any}", .{err});
        return null;
    };

    return path;
}

/// Linux: Try zenity, then kdialog, then fallback
fn pickFolderLinux(allocator: std.mem.Allocator) !?[]const u8 {
    // Try zenity first (most common)
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zenity", "--file-selection", "--directory" },
    }) catch {
        // zenity not available, try kdialog
        const result2 = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "kdialog", "--getexistingdirectory" },
        }) catch return null;

        if (result2.term != .Exited or result2.term.Exited != 0) {
            allocator.free(result2.stdout);
            allocator.free(result2.stderr);
            return null;
        }

        const path = std.mem.trimRight(u8, result2.stdout, "\n");
        if (path.len == 0) {
            allocator.free(result2.stdout);
            return null;
        }

        // Duplicate path without newline
        const duped = try allocator.dupe(u8, path);
        allocator.free(result2.stdout);
        allocator.free(result2.stderr);
        return duped;
    };

    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        allocator.free(result.stdout);
        return null;
    }

    const path = std.mem.trimRight(u8, result.stdout, "\n");
    if (path.len == 0) {
        allocator.free(result.stdout);
        return null;
    }

    // Duplicate path without newline
    const duped = try allocator.dupe(u8, path);
    allocator.free(result.stdout);
    return duped;
}

/// Windows: Use PowerShell with Windows Forms
fn pickFolderWindows(allocator: std.mem.Allocator) !?[]const u8 {
    const script =
        \\Add-Type -AssemblyName System.Windows.Forms
        \\$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        \\if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        \\    $dialog.SelectedPath
        \\}
    ;

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{
            "powershell.exe",
            "-WindowStyle",
            "Hidden",
            "-Command",
            script,
        },
    });

    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        allocator.free(result.stdout);
        return null;
    }

    const path = std.mem.trimRight(u8, result.stdout, "\r\n");
    if (path.len == 0) {
        allocator.free(result.stdout);
        return null;
    }

    const duped = try allocator.dupe(u8, path);
    allocator.free(result.stdout);
    return duped;
}

/// macOS: Use osascript (AppleScript)
fn pickFolderMac(allocator: std.mem.Allocator) !?[]const u8 {
    const script =
        \\set folderPath to choose folder with prompt "Select a workspace folder"
        \\return POSIX path of folderPath
    ;

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{
            "osascript",
            "-e",
            script,
        },
    });

    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        allocator.free(result.stdout);
        return null;
    }

    const path = std.mem.trimRight(u8, result.stdout, "\n");
    if (path.len == 0) {
        allocator.free(result.stdout);
        return null;
    }

    const duped = try allocator.dupe(u8, path);
    allocator.free(result.stdout);
    return duped;
}
