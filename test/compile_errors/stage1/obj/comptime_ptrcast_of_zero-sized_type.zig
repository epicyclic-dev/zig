fn foo() void {
    const node: struct {} = undefined;
    const vla_ptr = @ptrCast([*]const u8, &node);
    _ = vla_ptr;
}
comptime { foo(); }

// comptime ptrcast of zero-sized type
//
// tmp.zig:3:21: error: '*const struct:2:17' and '[*]const u8' do not have the same in-memory representation
