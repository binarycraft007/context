const std = @import("std");
const c = @cImport(@cInclude("fcontext/fcontext.h"));
const testing = std.testing;

var ctx: c.fcontext_t = undefined;
var ctx2: c.fcontext_t = undefined;

fn doo(t: c.fcontext_transfer_t) callconv(.C) void {
    //std.debug.print("DOO\n", .{});
    std.time.sleep(1000 * std.time.ns_per_ms);
    _ = c.jump_fcontext(t.ctx, null);
}

fn foo(t: c.fcontext_transfer_t) callconv(.C) void {
    //std.debug.print("FOO\n", .{});
    std.time.sleep(1000 * std.time.ns_per_ms);
    _ = c.jump_fcontext(ctx2, null);
    //std.debug.print("FOO2\n", .{});
    std.time.sleep(1000 * std.time.ns_per_ms);
    _ = c.jump_fcontext(t.ctx, null);
}

test "basic functionality" {
    var s = c.create_fcontext_stack(16 * 1024);
    defer c.destroy_fcontext_stack(&s);
    var s2 = c.create_fcontext_stack(0);
    defer c.destroy_fcontext_stack(&s2);

    ctx = c.make_fcontext(s.sptr, s.ssize, foo);
    ctx2 = c.make_fcontext(s2.sptr, s2.ssize, doo);

    _ = c.jump_fcontext(ctx, null);
    //std.debug.print("END\n", .{});
}
