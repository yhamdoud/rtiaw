const Vec3 = @import("vec.zig").Vec3;

pub const Ray = struct {
    const Self = @This();

    origin: Vec3,
    dir: Vec3,

    pub fn init(origin: Vec3, dir: Vec3) Ray {
        return Ray{ .origin = origin, .dir = dir };
    }

    pub fn at(self: *const Self, t: f32) Vec3 {
        return self.origin.add(self.dir.scale(t));
    }
};
