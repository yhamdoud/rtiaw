const std = @import("std");

const ArrayList = std.ArrayList;

const utils = @import("utils.zig");
const c = @import("c.zig");

const Vec3 = @import("vec.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const Sphere = @import("sphere.zig").Sphere;
const HitRecord = @import("sphere.zig").HitRecord;
const Camera = @import("camera.zig").Camera;
const Material = @import("materials.zig").Material;

var random: *std.rand.Random = undefined;

export fn glfwErrorCallback(err: c_int, description: [*c]const u8) void {
    std.debug.panic("GLFW error ({}): {s}\n", .{ err, description });
}

pub fn main() !void {
    @setFloatMode(std.builtin.FloatMode.Optimized);

    const width: i32 = 600;
    const height: i32 = 300;

    _ = c.glfwSetErrorCallback(glfwErrorCallback);

    if (c.glfwInit() == 0) return error.GlfwInitFailed;
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 6);
    c.glfwWindowHint(c.GLFW_FLOATING, 1);

    const window = c.glfwCreateWindow(width, height, "rtiaw", null, null) orelse
        return error.GlfwCreateWindowFailed;
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    if (c.gladLoadGLLoader(@ptrCast(
        fn ([*c]const u8) callconv(.C) ?*c_void,
        c.glfwGetProcAddress,
    )) == 0) return error.GlInitFailed;

    var pbo: c_uint = undefined;
    c.glGenBuffers(1, &pbo);
    c.glBindBuffer(c.GL_PIXEL_UNPACK_BUFFER, pbo);

    const buf_size = width * height * 4;
    const flags: c_uint = c.GL_MAP_WRITE_BIT | c.GL_MAP_PERSISTENT_BIT |
        c.GL_MAP_COHERENT_BIT;

    c.glNamedBufferStorage(pbo, buf_size, null, flags);
    const mapped_buf = @ptrCast([*]u8, c.glMapNamedBufferRange(pbo, 0, buf_size, flags).?);

    var tex: c_uint = undefined;
    c.glCreateTextures(c.GL_TEXTURE_2D, 1, &tex);
    c.glTextureStorage2D(tex, 1, c.GL_RGBA8, width, height);

    var framebuf: c_uint = undefined;
    c.glGenFramebuffers(1, &framebuf);
    c.glBindFramebuffer(c.GL_READ_FRAMEBUFFER, framebuf);
    c.glNamedFramebufferTexture(framebuf, c.GL_COLOR_ATTACHMENT0, tex, 0);

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    random = &prng.random();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var spheres = ArrayList(Sphere).init(&gpa.allocator);
    defer _ = spheres.deinit();

    try initializeScene(&spheres);

    const aspect_ratio = @intToFloat(f32, width) / @intToFloat(f32, height);
    const sample_count = 20;
    const bounce_count = 10;

    const camera = Camera.init(&.{
        .origin = Vec3.init(13, 2, 3),
        .target = Vec3.init(0, 0, 0),
        .up = Vec3.init(0, 1, 0),
        .vertical_fov = 20,
        .aspect_ratio = aspect_ratio,
        .aperture = 0.1,
        .focus_distance = 10,
        .random = random,
    });

    var stderr = std.io.getStdErr();

    const image_width_inv = 1.0 / @intToFloat(f32, width - 1);
    const image_height_inv = 1.0 / @intToFloat(f32, height - 1);

    var j: i32 = height - 1;
    while (j >= 0 and c.glfwWindowShouldClose(window) == 0) : (j -= 1) {
        defer {
            c.glfwPollEvents();
            c.glfwSwapBuffers(window);
        }

        try stderr.writer().print("\rScanlines remaining: {}", .{j});

        var i: i32 = 0;
        while (i < width) : (i += 1) {
            var col = Vec3.initAll(0);

            var s: i32 = 0;
            while (s < sample_count) : (s += 1) {
                const u = (@intToFloat(f32, i) + random.float(f32)) * image_width_inv;
                const v = (@intToFloat(f32, j) + random.float(f32)) * image_height_inv;
                const ray = camera.ray(u, v);
                col = col.add(rayColor(&ray, spheres.items, bounce_count));
            }

            col = col.div(sample_count)
                .sqrt(); // Gamma correction.

            const offset = @intCast(usize, (i + j * width) * 4);

            mapped_buf[offset + 0] = @floatToInt(u8, 255.99 * col.x);
            mapped_buf[offset + 1] = @floatToInt(u8, 255.99 * col.y);
            mapped_buf[offset + 2] = @floatToInt(u8, 255.99 * col.z);
            mapped_buf[offset + 3] = 1;
        }

        const zeroPtr = @intToPtr(*allowzero c_void, 0);
        c.glTextureSubImage2D(tex, 0, 0, 0, width, height, c.GL_RGBA, c.GL_UNSIGNED_BYTE, zeroPtr);
        c.glBlitNamedFramebuffer(framebuf, 0, 0, 0, width, height, 0, 0, width, height, c.GL_COLOR_BUFFER_BIT, c.GL_NEAREST);
    }

    while (c.glfwWindowShouldClose(window) == 0)
        c.glfwPollEvents();
}

fn initializeScene(spheres: *ArrayList(Sphere)) !void {
    var a: i32 = -11;
    while (a < 11) : (a += 1) {
        var b: i32 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = random.float(f32);
            const center = Vec3.init(
                @intToFloat(f32, a) + 0.9 * random.float(f32),
                0.2,
                @intToFloat(f32, b) + 0.9 * random.float(f32),
            );

            if ((center.sub(Vec3.init(4, 0.2, 0))).len() > 0.9) {
                try spheres.append(if (choose_mat < 0.8)
                    Sphere.init(
                        center,
                        0.2,
                        Material.lambertian(
                            Vec3.random(random).mul(Vec3.random(random)),
                        ),
                    )
                else if (choose_mat < 0.95)
                    Sphere.init(
                        center,
                        0.2,
                        Material.metal(
                            Vec3.random(random),
                            utils.randomRange(
                                utils.Range(f32){ .min = 0, .max = 0.5 },
                                random,
                            ),
                        ),
                    )
                else
                    Sphere.init(
                        center,
                        0.2,
                        Material.dielectric(1.5),
                    ));
            }
        }
    }

    try spheres.append(Sphere.init(
        Vec3.init(0, -1000, 0),
        1000,
        Material.lambertian(Vec3.initAll(0.5)),
    ));

    try spheres.append(Sphere.init(
        Vec3.init(0, 1, 0),
        1.0,
        Material.dielectric(1.5),
    ));

    try spheres.append(Sphere.init(
        Vec3.init(-4, 1, 0),
        1.0,
        Material.lambertian(Vec3.init(0.4, 0.2, 0.1)),
    ));

    try spheres.append(Sphere.init(
        Vec3.init(4, 1, 0),
        1.0,
        Material.metal(Vec3.init(0.7, 0.6, 0.5), 0),
    ));
}

fn rayColor(ray_in: *const Ray, spheres: []const Sphere, depth: u32) Vec3 {
    var t_range = utils.Range(f32){ .min = 0.001, .max = std.math.inf(f32) };

    var rec: HitRecord = undefined;
    var hit_anything = false;
    var material: Material = undefined;

    if (depth == 0) return Vec3.initAll(0);

    for (spheres) |sphere| {
        if (sphere.hit(ray_in, t_range, &rec)) {
            hit_anything = true;
            t_range.max = rec.t;
            material = rec.material.*;
        }
    }

    if (hit_anything) {
        var ray_out: Ray = undefined;
        var atten: Vec3 = undefined;

        const bounce = switch (material) {
            Material.Lambertian => |l| l.scatter(&rec, &atten, &ray_out, random),
            Material.Metal => |m| m.scatter(ray_in, &rec, &atten, &ray_out, random),
            Material.Dielectric => |d| d.scatter(ray_in, &rec, &atten, &ray_out, random),
        };

        return if (bounce) atten.mul(rayColor(&ray_out, spheres, depth - 1)) else Vec3.zero;
    }

    const unit_dir = ray_in.dir.normalize();
    const t = (unit_dir.y + 1) * 0.5;

    return Vec3.lerp(Vec3.initAll(1), Vec3.init(0.5, 0.7, 1.0), t);
}
