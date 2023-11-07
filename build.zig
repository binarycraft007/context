const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "context",
        .root_source_file = .{ .path = "src/context.zig" },
        .target = target,
        .optimize = optimize,
    });
    const t = lib.target_info.target;
    lib.linkLibC();
    switch (t.os.tag) {
        .windows => {
            switch (t.cpu.arch) {
                .x86_64 => {
                    inline for (x86_64_ms_pe_clang_gas) |src|
                        lib.addAssemblyFile(.{ .path = src });
                },
                .aarch64 => {
                    inline for (arm64_aapcs_pe_gas) |src|
                        lib.addAssemblyFile(.{ .path = src });
                },
                else => {},
            }
        },
        .linux => {
            switch (t.cpu.arch) {
                .x86_64 => {
                    inline for (x86_64_sysv_elf_gas) |src|
                        lib.addAssemblyFile(.{ .path = src });
                },
                .aarch64 => {
                    inline for (arm64_sysv_elf_gas) |src|
                        lib.addAssemblyFile(.{ .path = src });
                },
                else => {},
            }
        },
        .macos => {
            switch (t.cpu.arch) {
                .x86_64 => {
                    inline for (x86_64_sysv_macho_gas) |src|
                        lib.addAssemblyFile(.{ .path = src });
                },
                .aarch64 => {
                    inline for (arm64_aapcs_macho_gas) |src|
                        lib.addAssemblyFile(.{ .path = src });
                },
                else => {},
            }
        },
        else => {},
    }
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/context.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.linkLibrary(lib);

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}

const x86_64_ms_pe_clang_gas = [_][]const u8{
    "src/asm/jump_x86_64_ms_pe_clang_gas.S",
    "src/asm/make_x86_64_ms_pe_clang_gas.S",
    "src/asm/ontop_x86_64_ms_pe_clang_gas.S",
};

const arm64_aapcs_pe_gas = [_][]const u8{
    "src/asm/jump_arm64_aapcs_pe_gas.S",
    "src/asm/make_arm64_aapcs_pe_gas.S",
    "src/asm/ontop_arm64_aapcs_pe_gas.S",
};

const arm64_sysv_elf_gas = [_][]const u8{
    "src/asm/jump_arm64_aapcs_elf_gas.S",
    "src/asm/make_arm64_aapcs_elf_gas.S",
    "src/asm/ontop_arm64_aapcs_elf_gas.S",
};

const x86_64_sysv_elf_gas = [_][]const u8{
    "src/asm/jump_x86_64_sysv_elf_gas.S",
    "src/asm/make_x86_64_sysv_elf_gas.S",
    "src/asm/ontop_x86_64_sysv_elf_gas.S",
};

const x86_64_sysv_macho_gas = [_][]const u8{
    "src/asm/jump_x86_64_sysv_macho_gas.S",
    "src/asm/make_x86_64_sysv_macho_gas.S",
    "src/asm/ontop_x86_64_sysv_macho_gas.S",
};

const arm64_aapcs_macho_gas = [_][]const u8{
    "src/asm/jump_arm64_aapcs_macho_gas.S",
    "src/asm/make_arm64_aapcs_macho_gas.S",
    "src/asm/ontop_arm64_aapcs_macho_gas.S",
};
