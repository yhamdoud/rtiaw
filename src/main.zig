const std = @import("std");
const os = @import("os");

const ArrayList = std.ArrayList;

const utils = @import("utils.zig");
const c = @import("c.zig");

const Vec3 = @import("vec.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const Sphere = @import("sphere.zig").Sphere;
const HitRecord = @import("sphere.zig").HitRecord;
const Camera = @import("camera.zig").Camera;
const Material = @import("materials.zig").Material;

const width = 1280;
const height = 720;

const sample_count = 100;
const bounce_count = 25;

const ThreadContext = struct {
    idx: i32,
    chunk_size: i32,
    width: i32,
    height: i32,
    buf: [][3]u8,
    spheres: []const Sphere,
    camera: *const Camera,
};

pub fn main() !void {
    @setFloatMode(std.builtin.FloatMode.Optimized);

    _ = c.glfwSetErrorCallback(glfwErrorCallback);

    if (c.glfwInit() == 0) return error.GlfwInitFailed;
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 6);
    c.glfwWindowHint(c.GLFW_FLOATING, 1);
    c.glfwWindowHint(c.GLFW_RESIZABLE, 0);

    const window = c.glfwCreateWindow(width, height, "rtiaw", null, null) orelse
        return error.GlfwCreateWindowFailed;
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    if (c.gladLoadGLLoader(@ptrCast(
        fn ([*c]const u8) callconv(.C) ?*c_void,
        c.glfwGetProcAddress,
    )) == 0) return error.GlInitFailed;

    var buf: c_uint = undefined;
    c.glGenBuffers(1, &buf);
    c.glBindBuffer(c.GL_PIXEL_UNPACK_BUFFER, buf);

    const pixel_count = width * height;
    const flags: c_uint = c.GL_MAP_WRITE_BIT | c.GL_MAP_PERSISTENT_BIT |
        c.GL_MAP_COHERENT_BIT;

    c.glNamedBufferStorage(buf, pixel_count * 3, null, flags);
    var mapped_buf = @ptrCast(
        [*][3]u8,
        c.glMapNamedBufferRange(buf, 0, pixel_count * 3, flags).?,
    )[0..pixel_count];

    @memset(&mapped_buf[0], 0, @sizeOf(@TypeOf(mapped_buf.*)));

    var tex: c_uint = undefined;
    c.glCreateTextures(c.GL_TEXTURE_2D, 1, &tex);
    c.glTextureStorage2D(tex, 1, c.GL_RGB8, width, height);

    var framebuf: c_uint = undefined;
    c.glGenFramebuffers(1, &framebuf);
    c.glBindFramebuffer(c.GL_READ_FRAMEBUFFER, framebuf);
    c.glNamedFramebufferTexture(framebuf, c.GL_COLOR_ATTACHMENT0, tex, 0);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var spheres = ArrayList(Sphere).init(&gpa.allocator);
    defer _ = spheres.deinit();

    try initializeScene(&spheres);

    const camera = Camera.init(&.{
        .origin = Vec3.init(13, 2, 3),
        .target = Vec3.init(0, 0, 0),
        .up = Vec3.init(0, 1, 0),
        .vertical_fov = 20,
        .aspect_ratio = @intToFloat(f32, width) / @intToFloat(f32, height),
        .aperture = 0.1,
        .focus_distance = 10,
    });

    const thread_count = @intCast(i32, (try std.Thread.getCpuCount()) - 1);
    var threads = try ArrayList(std.Thread).initCapacity(&gpa.allocator, @intCast(usize, thread_count));
    defer _ = threads.deinit();

    var thread_idx: i32 = 0;
    while (thread_idx < thread_count) : (thread_idx += 1) {
        const ctx = ThreadContext{
            .idx = thread_idx,
            .chunk_size = @divTrunc(width * height, thread_count),
            .width = width,
            .height = height,
            .buf = mapped_buf,
            .spheres = spheres.items,
            .camera = &camera,
        };

        try threads.append(try std.Thread.spawn(.{}, traceRays, .{ctx}));
    }

    for (threads.items) |thread|
        thread.detach();

    const zeroPtr = @intToPtr(*allowzero c_void, 0);
    c.glfwSwapInterval(1);

    while (c.glfwWindowShouldClose(window) == 0) {
        defer {
            c.glfwPollEvents();
            c.glfwSwapBuffers(window);
        }

        c.glTextureSubImage2D(tex, 0, 0, 0, width, height, c.GL_RGB, c.GL_UNSIGNED_BYTE, zeroPtr);
        c.glBlitNamedFramebuffer(framebuf, 0, 0, 0, width, height, 0, 0, width, height, c.GL_COLOR_BUFFER_BIT, c.GL_NEAREST);
    }
}

fn traceRays(ctx: ThreadContext) void {
    const width_inv = 1.0 / @intToFloat(f32, ctx.width - 1);
    const height_inv = 1.0 / @intToFloat(f32, ctx.height - 1);

    const start_idx = ctx.idx * ctx.chunk_size;
    const stop_idx = std.math.min(
        start_idx + ctx.chunk_size,
        ctx.width * ctx.height,
    );

    var random = std.rand.DefaultPrng.init(@intCast(u64, ctx.idx)).random();

    var idx: i32 = start_idx;
    while (idx < stop_idx) : (idx += 1) {
        const i = @mod(idx, ctx.width);
        const j = @divTrunc(idx, ctx.width);
        var col = Vec3.initAll(0);

        var s: i32 = 0;
        while (s < sample_count) : (s += 1) {
            const u = (@intToFloat(f32, i) + random.float(f32)) * width_inv;
            const v = (@intToFloat(f32, j) + random.float(f32)) * height_inv;
            const ray = ctx.camera.ray(u, v, &random);
            col = col.add(rayColor(&ray, ctx.spheres, bounce_count, &random));
        }

        col = col.div(sample_count)
            .sqrt() // Gamma correction.
            .scale(255.99);

        const offset = @intCast(usize, i + j * ctx.width);
        ctx.buf[offset][0] = @floatToInt(u8, col.x);
        ctx.buf[offset][1] = @floatToInt(u8, col.y);
        ctx.buf[offset][2] = @floatToInt(u8, col.z);
    }
}

fn initializeScene(spheres: *ArrayList(Sphere)) !void {
    var rand = std.rand.DefaultPrng.init(42).random();

    var a: i32 = -11;
    while (a < 11) : (a += 1) {
        var b: i32 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = rand.float(f32);
            const center = Vec3.init(
                @intToFloat(f32, a) + 0.9 * rand.float(f32),
                0.2,
                @intToFloat(f32, b) + 0.9 * rand.float(f32),
            );

            if ((center.sub(Vec3.init(4, 0.2, 0))).len() > 0.9) {
                try spheres.append(if (choose_mat < 0.8)
                    Sphere.init(
                        center,
                        0.2,
                        Material.lambertian(
                            Vec3.random(&rand).mul(Vec3.random(&rand)),
                        ),
                    )
                else if (choose_mat < 0.95)
                    Sphere.init(
                        center,
                        0.2,
                        Material.metal(
                            Vec3.random(&rand),
                            utils.randomRange(
                                utils.Range(f32){ .min = 0, .max = 0.5 },
                                &rand,
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

fn rayColor(
    ray_in: *const Ray,
    spheres: []const Sphere,
    depth: u32,
    random: *std.rand.Random,
) Vec3 {
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

        return if (bounce) atten.mul(rayColor(&ray_out, spheres, depth - 1, random)) else Vec3.zero;
    }

    const unit_dir = ray_in.dir.normalize();
    const t = (unit_dir.y + 1) * 0.5;

    return Vec3.lerp(Vec3.initAll(1), Vec3.init(0.5, 0.7, 1.0), t);
}

export fn glfwErrorCallback(err: c_int, description: [*c]const u8) void {
    std.debug.panic("GLFW error ({}): {s}\n", .{ err, description });
}
