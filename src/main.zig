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

    const image_width: u32 = 400;
    const image_height: u32 = 200;
    const aspect_ratio = @intToFloat(f32, image_width) / @intToFloat(f32, image_height);

    const viewport_height = 2.0;
    const viewport_width = aspect_ratio * viewport_height;
    const focal_length = 1.0;

    const origin = Point3.initAll(0);
    const horizontal = Vec3.init(viewport_width, 0, 0);
    const vertical = Vec3.init(0, viewport_height, 0);
    const lower_left_corner = origin
        .sub(horizontal.div(2))
        .sub(vertical.div(2))
        .sub(Vec3.init(0, 0, focal_length));

    var stdout = std.io.bufferedWriter(std.io.getStdOut().writer());
    var stderr = std.io.getStdErr();

    try stdout.writer().print("P3\n{} {}\n255\n", .{ image_width, image_height });

    var j: u32 = 0;
    while (j < image_height) : (j += 1) {
        try stderr.writer().print("\rScanlines remaining: {}", .{image_height - 1 - j});

        var i: u32 = 0;
        while (i < image_width) : (i += 1) {
            const u = @intToFloat(f32, i) / @intToFloat(f32, image_width - 1);
            const v = @intToFloat(f32, image_height - 1 - j) / @intToFloat(f32, image_height - 1);

            const ray_end = lower_left_corner
                .add(horizontal.scale(u))
                .add(vertical.scale(v));

            const ray = Ray{ .origin = origin, .dir = ray_end.sub(origin) };

            const col = rayColor(&ray, spheres.items);

            try stdout.writer().print("{} {} {}\n", .{
                @floatToInt(u8, 255.99 * col.x),
                @floatToInt(u8, 255.99 * col.y),
                @floatToInt(u8, 255.99 * col.z),
            });
        }
    }

    try stdout.flush();
}
