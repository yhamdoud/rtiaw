const std = @import("std");
const vec = @import("vec.zig");

const Vec3 = vec.Vec3;
const Color = vec.Color;

pub fn main() !void {
    const width: u32 = 256;
    const height: u32 = 256;

    var stdout = std.io.bufferedWriter(std.io.getStdOut().writer());
    var stderr = std.io.bufferedWriter(std.io.getStdErr().writer());

    try stdout.writer().print("P3\n{} {}\n255\n", .{ width, height });

    var j: u32 = 0;
    while (j < height) : (j += 1) {
        try stderr.writer().print("\rScanlines remaining: {}", .{height - 1 - j});
        try stderr.flush();

        var i: u32 = 0;
        while (i < width) : (i += 1) {
            const col = Color.init(
                @intToFloat(f32, i) / @intToFloat(f32, width - 1),
                @intToFloat(f32, height - 1 - j) / @intToFloat(f32, height - 1),
                @intToFloat(f32, height - 1 - j) / @intToFloat(f32, height - 1),
            );

            try stdout.writer().print("{} {} {}\n", .{
                @floatToInt(u8, 255.99 * col.x),
                @floatToInt(u8, 255.99 * col.y),
                @floatToInt(u8, 255.99 * col.z),
            });
        }
    }

    try stdout.flush();
}
