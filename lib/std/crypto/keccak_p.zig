const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;

/// The Keccak-f permutation.
pub fn KeccakF(comptime f: u11) type {
    comptime assert(f > 200 and f <= 1600 and f % 200 == 0); // invalid bit size
    const T = std.meta.Int(.unsigned, f / 25);
    const Block = [25]T;

    const RC = [_]u64{
        0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000,
        0x000000000000808b, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
        0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
        0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003,
        0x8000000000008002, 0x8000000000000080, 0x000000000000800a, 0x800000008000000a,
        0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
    };

    const RHO = [_]u6{
        1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44,
    };

    const PI = [_]u5{
        10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1,
    };

    return struct {
        const Self = @This();

        /// Number of bytes in the state.
        pub const block_bytes = f / 8;

        st: Block = [_]T{0} ** 25,

        /// Initialize the state from a slice of bytes.
        pub fn init(bytes: [block_bytes]u8) Self {
            var self: Self = undefined;
            inline for (&self.st, 0..) |*r, i| {
                r.* = mem.readIntLittle(T, bytes[@sizeOf(T) * i ..][0..@sizeOf(T)]);
            }
            return self;
        }

        /// A representation of the state as bytes. The byte order is architecture-dependent.
        pub fn asBytes(self: *Self) *[block_bytes]u8 {
            return mem.asBytes(&self.st);
        }

        /// Byte-swap the entire state if the architecture doesn't match the required endianness.
        pub fn endianSwap(self: *Self) void {
            for (&self.st) |*w| {
                w.* = mem.littleTooNative(T, w.*);
            }
        }

        /// Set bytes starting at the beginning of the state.
        pub fn setBytes(self: *Self, bytes: []const u8) void {
            var i: usize = 0;
            while (i + @sizeOf(T) <= bytes.len) : (i += @sizeOf(T)) {
                self.st[i / @sizeOf(T)] = mem.readIntLittle(T, bytes[i..][0..@sizeOf(T)]);
            }
            if (i < bytes.len) {
                var padded = [_]u8{0} ** @sizeOf(T);
                mem.copy(u8, padded[0 .. bytes.len - i], bytes[i..]);
                self.st[i / @sizeOf(T)] = mem.readIntLittle(T, padded[0..]);
            }
        }

        /// XOR a byte into the state at a given offset.
        pub fn addByte(self: *Self, byte: u8, offset: usize) void {
            const z = @sizeOf(T) * @truncate(math.Log2Int(T), offset % @sizeOf(T));
            self.st[offset / @sizeOf(T)] ^= @as(T, byte) << z;
        }

        /// XOR bytes into the beginning of the state.
        pub fn addBytes(self: *Self, bytes: []const u8) void {
            var i: usize = 0;
            while (i + @sizeOf(T) <= bytes.len) : (i += @sizeOf(T)) {
                self.st[i / @sizeOf(T)] ^= mem.readIntLittle(T, bytes[i..][0..@sizeOf(T)]);
            }
            if (i < bytes.len) {
                var padded = [_]u8{0} ** @sizeOf(T);
                mem.copy(u8, padded[0 .. bytes.len - i], bytes[i..]);
                self.st[i / @sizeOf(T)] ^= mem.readIntLittle(T, padded[0..]);
            }
        }

        /// Extract the first bytes of the state.
        pub fn extractBytes(self: *Self, out: []u8) void {
            var i: usize = 0;
            while (i + @sizeOf(T) <= out.len) : (i += @sizeOf(T)) {
                mem.writeIntLittle(T, out[i..][0..@sizeOf(T)], self.st[i / @sizeOf(T)]);
            }
            if (i < out.len) {
                var padded = [_]u8{0} ** @sizeOf(T);
                mem.writeIntLittle(T, padded[0..], self.st[i / @sizeOf(T)]);
                mem.copy(u8, out[i..], padded[0 .. out.len - i]);
            }
        }

        /// XOR the first bytes of the state into a slice of bytes.
        pub fn xorBytes(self: *Self, out: []u8, in: []const u8) void {
            assert(out.len == in.len);

            var i: usize = 0;
            while (i + @sizeOf(T) <= in.len) : (i += @sizeOf(T)) {
                const x = mem.readIntNative(T, in[i..][0..@sizeOf(T)]) ^ mem.nativeToLittle(T, self.st[i / @sizeOf(T)]);
                mem.writeIntNative(T, out[i..][0..@sizeOf(T)], x);
            }
            if (i < in.len) {
                var padded = [_]u8{0} ** @sizeOf(T);
                mem.copy(u8, padded[0 .. in.len - i], in[i..]);
                const x = mem.readIntNative(T, &padded) ^ mem.nativeToLittle(T, self.st[i / @sizeOf(T)]);
                mem.writeIntNative(T, &padded, x);
                mem.copy(u8, out[i..], padded[0 .. in.len - i]);
            }
        }

        /// Set the words storing the bytes of a given range to zero.
        pub fn clear(self: *Self, from: usize, to: usize) void {
            mem.set(T, self.st[from / @sizeOf(T) .. (to + @sizeOf(T) - 1) / @sizeOf(T)], 0);
        }

        /// Clear the entire state, disabling compiler optimizations.
        pub fn secureZero(self: *Self) void {
            std.crypto.utils.secureZero(T, &self.st);
        }

        inline fn round(self: *Self, rc: T) void {
            const st = &self.st;

            // theta
            var t = [_]T{0} ** 5;
            inline for (0..5) |i| {
                inline for (0..5) |j| {
                    t[i] ^= st[j * 5 + i];
                }
            }
            inline for (0..5) |i| {
                inline for (0..5) |j| {
                    st[j * 5 + i] ^= t[(i + 4) % 5] ^ math.rotl(T, t[(i + 1) % 5], 1);
                }
            }

            // rho+pi
            var last = st[1];
            inline for (0..24) |i| {
                const x = PI[i];
                const tmp = st[x];
                st[x] = math.rotl(T, last, RHO[i]);
                last = tmp;
            }
            inline for (0..5) |i| {
                inline for (0..5) |j| {
                    t[j] = st[i * 5 + j];
                }
                inline for (0..5) |j| {
                    st[i * 5 + j] = t[j] ^ (~t[(j + 1) % 5] & t[(j + 2) % 5]);
                }
            }

            // iota
            st[0] ^= rc;
        }

        /// Apply a (possibly) reduced-round permutation to the state.
        pub fn permuteR(self: *Self, comptime rounds: u5) void {
            var i = RC.len - rounds;
            while (i < rounds - rounds % 3) : (i += 3) {
                self.round(RC[i]);
                self.round(RC[i + 1]);
                self.round(RC[i + 2]);
            }
            while (i < rounds) : (i += 1) {
                self.round(RC[i]);
            }
        }

        /// Apply a full-round permutation to the state.
        pub fn permute(self: *Self) void {
            self.permuteR(comptime 12 + 2 * math.log2(f / 25));
        }
    };
}

/// A generic Keccak-P state.
pub fn State(comptime f: u11, comptime capacity: u11, comptime delim: u8, comptime rounds: u5) type {
    comptime assert(f > 200 and f <= 1600 and f % 200 == 0); // invalid state size
    comptime assert(capacity < f and capacity % 8 == 0); // invalid capacity size

    return struct {
        const Self = @This();

        /// The block length, or rate, in bytes.
        pub const rate = KeccakF(f).block_bytes - capacity / 8;
        /// Keccak does not have any options.
        pub const Options = struct {};

        offset: usize = 0,
        buf: [rate]u8 = undefined,

        st: KeccakF(f) = .{},

        /// Absorb a slice of bytes into the sponge.
        pub fn absorb(self: *Self, bytes_: []const u8) void {
            var bytes = bytes_;
            if (self.offset > 0) {
                const left = math.min(rate - self.offset, bytes.len);
                mem.copy(u8, self.buf[self.offset..], bytes[0..left]);
                self.offset += left;
                if (self.offset == rate) {
                    self.offset = 0;
                    self.st.addBytes(self.buf[0..]);
                    self.st.permuteR(rounds);
                }
                if (left == bytes.len) return;
                bytes = bytes[left..];
            }
            while (bytes.len >= rate) {
                self.st.addBytes(bytes[0..rate]);
                self.st.permuteR(rounds);
                bytes = bytes[rate..];
            }
            if (bytes.len > 0) {
                self.st.addBytes(bytes[0..]);
                self.offset = bytes.len;
            }
        }

        /// Mark the end of the input.
        pub fn pad(self: *Self) void {
            self.st.addBytes(self.buf[0..self.offset]);
            self.st.addByte(delim, self.offset);
            self.st.addByte(0x80, rate - 1);
            self.st.permuteR(rounds);
            self.offset = 0;
        }

        /// Squeeze a slice of bytes from the sponge.
        pub fn squeeze(self: *Self, out: []u8) void {
            var i: usize = 0;
            while (i < out.len) : (i += rate) {
                const left = math.min(rate, out.len - i);
                self.st.extractBytes(out[i..][0..left]);
                self.st.permuteR(rounds);
            }
        }
    };
}
