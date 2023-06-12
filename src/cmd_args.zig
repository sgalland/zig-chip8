const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CommandLineArgumentsArrayList = std.ArrayList(CommandLineArgument);

pub fn Arg(comptime T: type) type {
    return struct {
        pub const ArgNode = struct {
            next: ?*ArgNode,

            help: []const u8,
            arg_prefix: []const u8,
            required: bool,
            default: T,
        };

        first: ?*ArgNode,
        last: ?*ArgNode,
    };
}

pub fn myCreateArgsList(node: Arg) []Arg {
    _ = node;
}

pub fn createCmdLineArgs(args: CommandLineArgumentsArrayList) void {
    for (args.items) |arg| {
        std.debug.print("prefix={s}, help={s}\n", .{ arg.arg_prefix, arg.help });
    }
}

pub const CommandLineArgumentParser = struct {
    const Self = @This();
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return CommandLineArgumentParser{
            .allocator = allocator,
        };
    }
};

pub const CommandLineArgument = struct {
    help: []const u8,
    arg_prefix: []const u8,
    required: bool = false,
};

pub fn CommandLineArgument2(comptime T: type) type {
    return struct {
        help: []const u8,
        arg_prefix: []const u8,
        required: bool,
        default: ?T,
    };
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
