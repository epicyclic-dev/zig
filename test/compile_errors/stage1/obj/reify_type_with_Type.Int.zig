const builtin = @import("std").builtin;
export fn entry() void {
    _ = @Type(builtin.Type.Int{
        .signedness = .signed,
        .bits = 8,
    });
}

// @Type with Type.Int
//
// tmp.zig:3:31: error: expected type 'std.builtin.Type', found 'std.builtin.Type.Int'
