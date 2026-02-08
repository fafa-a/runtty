pub const packages = struct {
    pub const @"webui-2.5.0-beta.4-pxqD5Rb7NwBVEwKyEzxwKAprzUIYjN20Y_Wffl_SWVdg" = struct {
        pub const build_root = "/home/fafa/.cache/zig/p/webui-2.5.0-beta.4-pxqD5Rb7NwBVEwKyEzxwKAprzUIYjN20Y_Wffl_SWVdg";
        pub const build_zig = @import("webui-2.5.0-beta.4-pxqD5Rb7NwBVEwKyEzxwKAprzUIYjN20Y_Wffl_SWVdg");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"zig_webui-2.5.0-beta.4-M4z7zfBlAQDCSVNk_B9TZkOw3PE1NsKKrabgVforJoaV" = struct {
        pub const build_root = "/home/fafa/.cache/zig/p/zig_webui-2.5.0-beta.4-M4z7zfBlAQDCSVNk_B9TZkOw3PE1NsKKrabgVforJoaV";
        pub const build_zig = @import("zig_webui-2.5.0-beta.4-M4z7zfBlAQDCSVNk_B9TZkOw3PE1NsKKrabgVforJoaV");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "webui", "webui-2.5.0-beta.4-pxqD5Rb7NwBVEwKyEzxwKAprzUIYjN20Y_Wffl_SWVdg" },
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "zig_webui", "zig_webui-2.5.0-beta.4-M4z7zfBlAQDCSVNk_B9TZkOw3PE1NsKKrabgVforJoaV" },
};
