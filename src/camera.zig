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
    u: Vec3,
    v: Vec3,
    w: Vec3,
    lens_radius: f32,

    pub const Args = struct {
        origin: Vec3,
        target: Vec3,
        up: Vec3,
        vertical_fov: f32,
        aspect_ratio: f32,
        aperture: f32,
        focus_distance: f32,
    };

    pub fn init(args: *const Args) Self {
        const theta = utils.toRadians(args.vertical_fov);
        const h = std.math.tan(theta / 2);

        const viewport_height = 2.0 * h;
        const viewport_width = args.aspect_ratio * viewport_height;

        // Calculate orthonormal camera basis.
        const w = args.origin.sub(args.target).normalize();
        const u = args.up.cross(w);
        const v = w.cross(u);

        const horizontal = u.scale(args.focus_distance * viewport_width);
        const vertical = v.scale(args.focus_distance * viewport_height);

        return Self{
            .origin = args.origin,
            .horizontal = horizontal,
            .vertical = vertical,
            .lower_left_corner = args.origin
                .sub(horizontal.scale(0.5))
                .sub(vertical.scale(0.5))
                .sub(w.scale(args.focus_distance)),
            .u = u,
            .v = v,
            .w = w,
            .lens_radius = args.aperture / 2,
        };
    }

    pub fn ray(self: *const Self, s: f32, t: f32, random: *std.rand.Random) Ray {
        // Generate random rays originating from inside a disk centered at the
        // camera origin to simulate defocus blur.
        var disk = utils.randomVecInUnitSphere(random);
        disk.z = 0;
        disk = disk.scale(self.lens_radius);

        const offset = self.u.scale(disk.x).add(self.u.scale(disk.y));
        const origin = self.origin.add(offset);

        const end = self.lower_left_corner
            .add(self.horizontal.scale(s))
            .add(self.vertical.scale(t));

        return Ray{ .origin = origin, .dir = end.sub(origin) };
    }
};
