const std = @import("std");

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
            const r = @intToFloat(f32, i) / @intToFloat(f32, width - 1);
            const g = @intToFloat(f32, height - 1 - j) / @intToFloat(f32, height - 1);
            const b = 0.25;

            var ir = @floatToInt(u8, 255.99 * r);
            var ig = @floatToInt(u8, 255.99 * g);
            var ib = @floatToInt(u8, 255.99 * b);

            try stdout.writer().print("{} {} {}\n", .{ ir, ig, ib });
        }
    }

    try stdout.flush();
}
