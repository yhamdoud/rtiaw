const Vec3 = @import("vec.zig").Vec3;
const Ray = @import("ray.zig").Ray;

pub const Camera = struct {
    const Self = @This();

    origin: Vec3,
    horizontal: Vec3,
    vertical: Vec3,
    lower_left_corner: Vec3,

    pub fn init(aspect_ratio: f32) Self {
        const viewport_height = 2.0;
        const viewport_width = aspect_ratio * viewport_height;
        const focal_length = 1.0;
        const origin = Vec3.initAll(0);
        const horizontal = Vec3.init(viewport_width, 0, 0);
        const vertical = Vec3.init(0, viewport_height, 0);

        return Self{
            .origin = origin,
            .horizontal = horizontal,
            .vertical = vertical,
            .lower_left_corner = origin
                .sub(horizontal.div(2))
                .sub(vertical.div(2))
                .sub(Vec3.init(0, 0, focal_length)),
        };
    }

    pub fn ray(self: *const Self, u: f32, v: f32) Ray {
        const end = self.lower_left_corner
            .add(self.horizontal.scale(u))
            .add(self.vertical.scale(v));

        return Ray{ .origin = self.origin, .dir = end.sub(self.origin) };
    }
};
