const std = @import("std");

const utils = @import("utils.zig");

const Vec3 = @import("vec.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("sphere.zig").HitRecord;

pub const Material = union(enum) {
    Lambertian: Lambertian,
    Metal: Metal,

    pub fn lambertian(albedo: Vec3) Material {
        return Material{ .Lambertian = Lambertian{ .albedo = albedo } };
    }

    pub fn metal(albedo: Vec3) Material {
        return Material{ .Metal = Metal{ .albedo = albedo } };
    }
};

pub const Lambertian = struct {
    albedo: Vec3,

    pub fn scatter(
        self: *const @This(),
        rec: *const HitRecord,
        atten: *Vec3,
        out: *Ray,
        random: *std.rand.Random,
    ) bool {
        var scatter_dir = rec.normal.add(utils.randomUnitVec(random));

        // Catch degenerate scatter direction.
        if (scatter_dir.approxEqAbs(Vec3.zero, 10 * std.math.epsilon(f32)))
            scatter_dir = rec.normal;

        out.origin = rec.point;
        out.dir = scatter_dir;
        atten.* = self.albedo;

        return true;
    }
};

pub const Metal = struct {
    albedo: Vec3,

    pub fn scatter(
        self: *const @This(),
        in: *const Ray,
        rec: *const HitRecord,
        atten: *Vec3,
        out: *Ray,
    ) bool {
        const reflect_dir = Vec3.reflect(in.dir.normalize(), rec.normal);

        out.origin = rec.point;
        out.dir = reflect_dir;
        atten.* = self.albedo;

        return out.dir.dot(rec.normal) > 0;
    }
};
