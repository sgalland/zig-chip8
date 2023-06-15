const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Arg = struct {
    const Self = @This();

    pub const ArgNode = struct {
        next: ?*ArgNode,

        name: []const u8,
        help: []const u8,
        arg_prefix: []const u8,
        required: bool = false,
        default: ?[]const u8 = undefined,
        default_type: ?enum { INT, FLOAT, BOOL, STRING } = undefined,
        valid_values: [][]const u8 = undefined,
        value: []const u8 = undefined,
        value_len: usize = 0,
    };

    allocator: Allocator = undefined,
    first: ?*ArgNode,
    last: ?*ArgNode,

    pub fn deinit(self: *Self) void {
        var arg_item = self.first;
        while (arg_item) |arg| {
            if (arg.value_len > 0) self.allocator.free(arg.value);
            arg_item = arg.next orelse null;
        }
    }
};

pub fn printHelp(args: Arg) void {
    var arg_item = args.first;
    while (arg_item) |arg| {
        std.debug.print("\t{s}\t{s}\n", .{ arg.arg_prefix, arg.help });
        arg_item = arg.next orelse null;
    }
}

pub fn processCommandLineArgs(allocator: Allocator, args: *Arg) !void {
    var cmd_args = try std.process.argsWithAllocator(allocator);
    defer cmd_args.deinit();

    args.allocator = allocator;

    var args_list = std.ArrayList([:0]const u8).init(args.allocator);
    defer args_list.clearAndFree();

    while (cmd_args.next()) |arg| {
        try args_list.append(arg);
    }

    var current_node = args.first;
    while (current_node) |node| {
        for (args_list.items) |arg| {
            if (std.mem.startsWith(u8, arg, node.arg_prefix)) {
                const extracted_param = if (extractParam(arg, node.arg_prefix)) |p| p[0..] else null;

                if (extracted_param) |param| {
                    const param_data = try args.allocator.alloc(u8, param.len);
                    @memcpy(param_data, param);

                    node.value = param_data;
                    node.value_len = param_data.len;
                }
            }
        }

        if (node.required and node.value_len == 0) {
            std.debug.print("\nRequired parameter {s} was not found.\n\n", .{node.arg_prefix});
            printHelp(args.*);
            std.os.exit(0);
        } else if (node.value_len == 0) {
            if (node.default) |default_value| {
                const param_data = try args.allocator.alloc(u8, default_value.len);
                @memcpy(param_data, default_value);

                node.value = param_data;
                node.value_len = default_value.len;
            }
        }

        current_node = current_node.?.next;
    }
}

fn extractParam(param: [:0]const u8, pattern: []const u8) ?[]const u8 {
    const pattern_index = std.mem.indexOf(u8, param, pattern);
    if (pattern_index) |index| {
        const len = index + pattern.len;
        const post_pattern = param[len..];
        const output = if (std.mem.startsWith(u8, post_pattern, "\"") and std.mem.endsWith(u8, post_pattern, "\"")) post_pattern[1 .. post_pattern.len - 1] else post_pattern;
        return output;
    }

    return null;
}
