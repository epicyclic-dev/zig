pub fn testTrickyDefer() !void {
    defer canFail() catch {};

    defer try canFail();

    const a = maybeInt() orelse return;
}

fn canFail() anyerror!void { }

pub fn maybeInt() ?i32 {
    return 0;
}

export fn entry() usize { return @sizeOf(@TypeOf(testTrickyDefer)); }

// return from defer expression
//
// tmp.zig:4:11: error: 'try' not allowed inside defer expression
