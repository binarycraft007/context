const std = @import("std");
const os = std.os;
const windows = os.windows;
const mem = std.mem;
const builtin = @import("builtin");

pub const Context = ?*anyopaque;
pub const ContextTransfer = extern struct {
    ctx: Context = mem.zeroes(Context),
    data: ?*anyopaque = mem.zeroes(?*anyopaque),
};

pub const ContextFn = ?*const fn (ContextTransfer) callconv(.C) void;
pub extern fn jump_fcontext(Context, ?*anyopaque) ContextTransfer;
pub extern fn make_fcontext(?*anyopaque, usize, ContextFn) Context;
pub extern fn ontop_fcontext(Context, ?*anyopaque, ContextFn) ContextTransfer;

const Stack = struct {
    ptr: ?*anyopaque,
    size: usize,

    fn getPageSize() usize {
        return mem.page_size;
    }

    fn getMinSize() usize {
        return 32 * 1024;
    }

    fn getMaxSize() usize {
        if (builtin.os.tag == .windows) {
            return 1 * 1024 * 1024 * 1024;
        } else {
            var limit = std.os.getrlimit(.STACK) catch {
                return 1 * 1024 * 1024 * 1024;
            };
            return @intCast(limit.max);
        }
    }

    fn getDefaultSize() usize {
        return 128 * 1024;
    }

    pub fn create(const_size: usize) !Stack {
        var size = const_size;
        var stack: Stack = undefined;
        if (size == 0) size = getDefaultSize();
        var min_size = getMinSize();
        var max_size = getMaxSize();
        if (size < min_size) size = min_size;
        if (size > max_size) size = max_size;
        var float: f64 = @floatFromInt((size / getPageSize()));
        var pages: usize = @intFromFloat(@floor(float));
        std.debug.assert(pages >= 2);
        var size_final = pages * getPageSize();
        std.debug.assert(size_final != 0 and size != 0);
        std.debug.assert(size_final <= size);

        if (builtin.os.tag == .windows) {
            var vp = try windows.VirtualAlloc(
                null,
                size_final,
                windows.MEM_COMMIT,
                windows.PAGE_READWRITE,
            );
            var old_options: windows.DWORD = undefined;
            try windows.VirtualProtect(
                vp,
                getPageSize(),
                windows.PAGE_READWRITE | windows.PAGE_GUARD,
                &old_options,
            );
            var vp_u8: [*]u8 = @alignCast(@ptrCast(vp));
            stack.ptr = vp_u8 + size_final;
            stack.size = size_final;
        } else {
            var vp = try os.mmap(
                null,
                size_final,
                os.PROT.READ | os.PROT.WRITE,
                os.MAP.PRIVATE | os.MAP.ANONYMOUS,
                -1,
                0,
            );
            try os.mprotect(vp[0..getPageSize()], os.PROT.NONE);
            stack.ptr = vp.ptr + size_final;
            stack.size = vp.len;
        }
        return stack;
    }

    pub fn destroy(self: *Stack) void {
        var vp: *anyopaque = undefined;
        std.debug.assert(self.size >= getMinSize());
        std.debug.assert(self.size <= getMaxSize());
        vp = @as([*]u8, @ptrCast(self.ptr)) - self.size;
        if (builtin.os.tag == .windows) {
            windows.VirtualFree(vp, 0, windows.MEM_RELEASE);
        } else {
            const PagePtr = [*]align(mem.page_size) u8;
            var ptr: PagePtr = @alignCast(@ptrCast(vp));
            os.munmap(ptr[0..self.size]);
        }
    }
};

test "basic functionality" {
    const S = struct {
        var ctx: Context = undefined;
        var ctx2: Context = undefined;

        fn doo(t: ContextTransfer) callconv(.C) void {
            //std.debug.print("DOO\n", .{});
            std.time.sleep(1000 * std.time.ns_per_ms);
            _ = jump_fcontext(t.ctx, null);
        }

        fn foo(t: ContextTransfer) callconv(.C) void {
            //std.debug.print("FOO\n", .{});
            std.time.sleep(1000 * std.time.ns_per_ms);
            _ = jump_fcontext(ctx2, null);
            //std.debug.print("FOO2\n", .{});
            std.time.sleep(1000 * std.time.ns_per_ms);
            _ = jump_fcontext(t.ctx, null);
        }
    };

    var s = try Stack.create(16 * 1024);
    defer s.destroy();
    var s2 = try Stack.create(0);
    defer s2.destroy();

    S.ctx = make_fcontext(s.ptr, s.size, S.foo);
    S.ctx2 = make_fcontext(s2.ptr, s2.size, S.doo);

    _ = jump_fcontext(S.ctx, null);
    //std.debug.print("END\n", .{});
}
