const x = @import("builtin").bogus;
export fn entry() usize { return @sizeOf(@TypeOf(x)); }

// bogus compile var
//
// tmp.zig:1:29: error: container 'builtin' has no member called 'bogus'
