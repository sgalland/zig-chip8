const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Arg = struct {
    pub const ArgNode = struct {
        next: ?*ArgNode,

        help: []const u8,
        arg_prefix: []const u8,
        required: bool = false,
        default: ?[]const u8 = undefined,
        default_type: ?enum { INT, BOOL, STRING } = undefined,
    };

    first: ?*ArgNode,
    last: ?*ArgNode,
};

pub fn createCmdLineArgs(allocator: Allocator, args: Arg) !void {
    var cmd_args = try std.process.argsWithAllocator(allocator);
    defer cmd_args.deinit();

    var current_node = args.first;
    while (cmd_args.next()) |arg| {
        std.debug.print("{s}\n", .{arg});
        while (current_node.?.next) |node| {
            if (std.mem.startsWith(u8, arg, node.arg_prefix)) {
                const param = if (extractParam(arg, node.arg_prefix)) |p| p[0..] else "";

                if (node.required and param.len == 0) {
                    std.debug.print("Required field {s} was not found.\n", .{node.arg_prefix});
                    std.debug.print("{s}\n", .{node.help});
                    std.os.exit(0);
                }
            }

            current_node = current_node.?.next;
        }

        current_node = args.first;
    }
}

fn extractParam(param: [:0]const u8, pattern: []const u8) ?[]u8 {
    const pattern_index = std.mem.indexOf(u8, param, pattern);
    if (pattern_index) |index| {
        const len = index + pattern.len;
        var output: []u8 = undefined;
        _ = std.mem.replace(u8, param[len..], "\"", "", output);
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
