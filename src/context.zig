const std = @import("std");
const builtin = @import("builtin");

const Stack = struct {
    const min_stack_size = if (builtin.os.tag == .windows) 8192 else 4096;
};
