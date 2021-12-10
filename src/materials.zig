const std = @import("std");

const utils = @import("utils.zig");

const Vec3 = @import("vec.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("sphere.zig").HitRecord;

pub const Material = union(enum) {
    Lambertian: Lambertian,
    Metal: Metal,
    Dielectric: Dielectric,

    pub fn lambertian(albedo: Vec3) Material {
        return Material{ .Lambertian = Lambertian{ .albedo = albedo } };
    }

    pub fn metal(albedo: Vec3, fuzz: f32) Material {
        return Material{ .Metal = Metal{ .albedo = albedo, .fuzz = fuzz } };
    }

    pub fn dielectric(ior: f32) Material {
        return Material{ .Dielectric = Dielectric{ .ior = ior } };
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
    fuzz: f32,

    pub fn scatter(
        self: *const @This(),
        in: *const Ray,
        rec: *const HitRecord,
        atten: *Vec3,
        out: *Ray,
        random: *std.rand.Random,
    ) bool {
        const reflect_dir = Vec3.reflect(in.dir.normalize(), rec.normal);

        out.origin = rec.point;
        out.dir = reflect_dir
            .add(utils.randomVecInUnitSphere(random).scale(self.fuzz));
        atten.* = self.albedo;

        return out.dir.dot(rec.normal) > 0;
    }
};

pub const Dielectric = struct {
    ior: f32,

    pub fn scatter(
        self: *const @This(),
        in: *const Ray,
        rec: *const HitRecord,
        atten: *Vec3,
        out: *Ray,
        random: *std.rand.Random,
    ) bool {
        // Air has an index of refraction of 1.
        const ior_ratio = if (rec.front_face) 1 / self.ior else self.ior;

        const unit_dir = in.dir.normalize();

        const cos_theta = @minimum(unit_dir.neg().dot(rec.normal), 1.0);
        const sin_theta = @sqrt(1 - cos_theta * cos_theta);

        const refl = reflectance(cos_theta, ior_ratio);

        // Consider total internal reflection.
        out.dir = if (ior_ratio * sin_theta > 1 or refl > random.float(f32))
            Vec3.reflect(unit_dir, rec.normal)
        else
            Vec3.refract(unit_dir, rec.normal, ior_ratio);

        out.origin = rec.point;
        atten.* = Vec3.initAll(1);

        return true;
    }

    // Calculate reflectance using Schlick's approximation.
    fn reflectance(cosine: f32, ior: f32) f32 {
        var r0 = (1 - ior) / (1 + ior);
        r0 = r0 * r0;
        return r0 + (1 - r0) * std.math.pow(f32, 1 - cosine, 5);
    }
};
