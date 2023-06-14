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
        value: []u8 = undefined,
    };

    allocator: Allocator = undefined,
    first: ?*ArgNode,
    last: ?*ArgNode,

    pub fn deinit(self: *Self) void {
        var arg_item = self.first;
        while (arg_item) |arg| {
            // self.allocator.free(arg.value);
            arg_item = arg.next orelse null;
        }
    }
};

pub fn processCommandLineArgs(allocator: Allocator, args: *Arg) !void {
    var cmd_args = try std.process.argsWithAllocator(allocator);
    defer cmd_args.deinit();

    args.allocator = allocator;

    var current_node = args.first;
    while (cmd_args.next()) |arg| {
        while (current_node) |node| {
            if (std.mem.startsWith(u8, arg, node.arg_prefix)) {
                const extracted_param = if (extractParam(arg, node.arg_prefix)) |p| p[0..] else null;

                if (node.required and (extracted_param == null or extracted_param.?.len == 0)) {
                    std.debug.print("Required field {s} was not found.\n", .{node.arg_prefix});
                    std.os.exit(0);
                } else if (extracted_param) |param| {
                    const param_data = try args.allocator.alloc(u8, param.len);

                    for (param, 0..param.len) |c, i| {
                        param_data[i] = c;
                    }

                    node.value = param_data;
                } else if (node.default) |default_value| {
                    _ = default_value;
                    // std.debug.print("can you see that\n", .{});
                    // std.debug.print("found default={s}\n", .{default_value});
                    // node.value = @constCast(default_value);
                }
            }

            current_node = current_node.?.next;
        }

        current_node = args.first;
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

// //TODO: Need to move argument checking to another file
// while (cmd_args.next()) |arg| {
//     std.debug.print("Command line arg: {s}\n", .{arg});

//     if (std.mem.startsWith(u8, arg, "-r=")) {
//         const rom_name = extractParam(arg, "-r=");
//         if (rom_name) |name| {
//             var trimmed_name: []u8 = undefined;

//             if (std.mem.containsAtLeast(u8, name, 1, "\"")) {
//                 _ = std.mem.replace(u8, name, "\"", "", trimmed_name);
//             } else {
//                 std.mem.copyForwards(u8, trimmed_name, name);
//             }

//             rom = @ptrCast([:0]const u8, trimmed_name);
//         }
//     }
// }

// if (rom.len == 0) {
//     std.debug.print("A rom is required. Please specify with -r=\"<rom name>\"\n", .{});
//     std.os.exit(0);
// }
// //TODO: Need to move argument checking to another file
