const std = @import("std");

const ArrayList = std.ArrayList;

const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Color = vec.Color;
const Ray = @import("ray.zig").Ray;
const Sphere = @import("sphere.zig").Sphere;
const HitRecord = @import("sphere.zig").HitRecord;
const Range = @import("utils.zig").Range;
const Camera = @import("camera.zig").Camera;

fn rayColor(ray: *const Ray, spheres: []const Sphere) Color {
    var t_range = Range(f32){ .min = 0, .max = std.math.inf(f32) };

    var rec: HitRecord = undefined;
    var hit_anything = false;

    for (spheres) |sphere| {
        if (sphere.hit(ray, t_range, &rec)) {
            hit_anything = true;
            t_range.max = rec.t;
        }
    }

    if (hit_anything)
        return rec.normal.add(Vec3.initAll(1)).scale(0.5);

    const unit_dir = ray.dir.normalize();
    const t = (unit_dir.y + 1) * 0.5;

    return Color.lerp(Color.initAll(1), Color.init(0.5, 0.7, 1.0), t);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var spheres = ArrayList(Sphere).init(&gpa.allocator);
    defer _ = spheres.deinit();

    try spheres.append(Sphere.init(Vec3.init(0, 0, -1), 0.5));
    try spheres.append(Sphere.init(Vec3.init(0, -100.5, -1), 100));

    const image_width: u32 = 600;
    const image_height: u32 = 300;
    const aspect_ratio = @intToFloat(f32, image_width) / @intToFloat(f32, image_height);
    const sample_count = 100;

    const camera = Camera.init(aspect_ratio);

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = &prng.random();

    var stdout = std.io.bufferedWriter(std.io.getStdOut().writer());
    var stderr = std.io.getStdErr();

    try stdout.writer().print("P3\n{} {}\n255\n", .{ image_width, image_height });

    const image_width_inv = 1.0 / @intToFloat(f32, image_width - 1);
    const image_height_inv = 1.0 / @intToFloat(f32, image_height - 1);

    var j: u32 = 0;
    while (j < image_height) : (j += 1) {
        try stderr.writer().print("\rScanlines remaining: {}", .{image_height - 1 - j});

        var i: u32 = 0;
        while (i < image_width) : (i += 1) {
            var col = Vec3.initAll(0);

            var s: u32 = 0;
            while (s < sample_count) : (s += 1) {
                const u = (@intToFloat(f32, i) + rand.float(f32)) * image_width_inv;
                const v = (@intToFloat(f32, image_height - 1 - j) + rand.float(f32)) * image_height_inv;
                const ray = camera.ray(u, v);
                col = col.add(rayColor(&ray, spheres.items));
            }

            col = col.div(sample_count);

            try stdout.writer().print("{} {} {}\n", .{
                @floatToInt(u8, 255.99 * col.x),
                @floatToInt(u8, 255.99 * col.y),
                @floatToInt(u8, 255.99 * col.z),
            });
        }
    }

    try stdout.flush();
}
