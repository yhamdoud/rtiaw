const std = @import("std");

const utils = @import("utils.zig");

const Vec3 = @import("vec.zig").Vec3;
const Ray = @import("ray.zig").Ray;

pub const Camera = struct {
    const Self = @This();

    origin: Vec3,
    horizontal: Vec3,
    vertical: Vec3,
    lower_left_corner: Vec3,

    pub const Args = struct {
        origin: Vec3,
        target: Vec3,
        up: Vec3,
        vertical_fov: f32,
        aspect_ratio: f32,
    };

    pub fn init(args: Args) Self {
        const theta = utils.degreesToRadians(args.vertical_fov);
        const h = std.math.tan(theta / 2);

        const viewport_height = 2.0 * h;
        const viewport_width = args.aspect_ratio * viewport_height;

        // Calculate orthonormal camera basis.
        const w = args.origin.sub(args.target).normalize();
        const u = args.up.cross(w);
        const v = w.cross(u);

        const horizontal = u.scale(viewport_width);
        const vertical = v.scale(viewport_height);

        return Self{
            .origin = args.origin,
            .horizontal = horizontal,
            .vertical = vertical,
            .lower_left_corner = args.origin
                .sub(horizontal.scale(0.5))
                .sub(vertical.scale(0.5))
                .sub(w),
        };
    }

    pub fn ray(self: *const Self, s: f32, t: f32) Ray {
        const end = self.lower_left_corner
            .add(self.horizontal.scale(s))
            .add(self.vertical.scale(t));

        return Ray{ .origin = self.origin, .dir = end.sub(self.origin) };
    }
};
