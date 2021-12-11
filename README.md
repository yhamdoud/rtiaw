# Ray Tracing in One Weekend using Zig

![cover](https://user-images.githubusercontent.com/18217298/145691087-0e5ca3db-af4c-4924-a235-c193d19b27bb.png)

This is a Zig implementation of [*Ray Tracing in One Weekend*](https://raytracing.github.io/books/RayTracingInOneWeekend.html) by Peter Shirley.
The structure of the path tracer roughly follows the book, using idiomatic Zig constructs when possible.
Notably, the usage of runtime polymorphism in the material system is substituted with tagged unions.

Some other additions of my own include rendering the results to a window using OpenGL and multithreading.

## Dependencies

- Zig 0.9.0
- GLFW
- Glad (vendored)

## Building

`$ zig build run -Drelease-fast=true`