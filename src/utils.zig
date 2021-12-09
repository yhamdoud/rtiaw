const std = @import("std");

const Vec3 = @import("vec.zig").Vec3;

pub fn Range(comptime T: type) type {
    return struct {
        const Self = @This();

        min: T,
        max: T,

        pub fn contains(self: *const Self, value: T) bool {
            return value >= self.min and value <= self.max;
        }
    };
}

pub fn randomRange(range: Range(f32), random: *std.rand.Random) f32 {
    return range.min + random.float(f32) * (range.max - range.min);
}

// TODO: Incorrect.
pub fn randomUnitVec(random: *std.rand.Random) Vec3 {
    const range = Range(f32){ .min = -1, .max = 1 };
    return Vec3.init(
        randomRange(range, random),
        randomRange(range, random),
        randomRange(range, random),
    ).normalize();
}
