export fn entry() void {
    _ = @intToPtr(*anyopaque, ~@as(usize, @import("std").math.maxInt(usize)) - 1);
}

// integer underflow error
//
// :2:78: error: operation caused overflow
