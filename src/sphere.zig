const Vec3 = @import("vec.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const Range = @import("utils.zig").Range;
const Material = @import("materials.zig").Material;

pub const Sphere = struct {
    const Self = @This();

    center: Vec3,
    radius: f32,
    material: Material,

    pub fn init(center: Vec3, radius: f32, material: Material) Self {
        return Self{ .center = center, .radius = radius, .material = material };
    }

    pub fn hit(self: *const Self, ray: *const Ray, t: Range(f32), rec: *HitRecord) bool {
        const oc = ray.origin.sub(self.center);

        const a = ray.dir.len2();
        const b_half = oc.dot(ray.dir);
        const c = oc.len2() - self.radius * self.radius;

        const discriminant = b_half * b_half - a * c;
        if (discriminant < 0) return false;

        // Find the nearest root that lies in the given range.
        const d_sqrt = @sqrt(discriminant);
        var root = (-b_half - d_sqrt) / a;
        if (!t.contains(root)) {
            root = (-b_half + d_sqrt) / a;
            if (!t.contains(root)) return false;
        }

        rec.t = root;
        rec.point = ray.at(rec.t);
        rec.set_face_normal(ray, rec.point.sub(self.center).div(self.radius));
        rec.material = &self.material;

        return true;
    }
};

pub const HitRecord = struct {
    point: Vec3,
    normal: Vec3,
    t: f32,
    front_face: bool,
    material: *const Material,

    pub fn set_face_normal(
        self: *@This(),
        ray: *const Ray,
        outward_normal: Vec3,
    ) void {
        self.front_face = ray.dir.dot(outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else outward_normal.neg();
    }
};
