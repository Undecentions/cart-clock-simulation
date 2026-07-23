const std = @import("std");
const cart_clock_simulation = @import("cart_clock_simulation");

// Currently needs uncommenting and commenting of stuff to see different output data
// Might figure out a better CLI thing later

pub fn main() void {
    test_one_clock();
    // run_clocks();
}

fn is_clock_valid(instance: *cart_clock_simulation.Instance) bool {
    const blocks = instance.world.blocks;
    // Maybe figure out a better way to format all this
    // zig fmt: off
    return (
        (
            blocks[2][1] != .cherry_trapdoor_west
            and blocks[2][1] != .amethyst_cluster
            and blocks[2][1] != .large_amethyst_bud
            and blocks[2][1] != .medium_amethyst_bud
        )
        or blocks[3][1] == .air
    )
    and (blocks[1][1] != .cherry_trapdoor_east or blocks[0][1] == .air)
    and (
        (
            blocks[1][0] != .powered_rail
            and blocks[1][0] != .powered_rail_waterlogged
        )
        or blocks[0][1] == .air
    )
    and (
        (
            blocks[1][0] != .powered_rail_raised
            and blocks[1][0] != .powered_rail_raised_waterlogged
        ) or (
            blocks[0][1] != .air
            and blocks[3][1] != .honey_block
            and blocks[3][1] != .cherry_leaves
        )
    );
    // zig fmt: on
}

fn run_clock(instance: *cart_clock_simulation.Instance) void {
    if (is_clock_valid(instance)) {
        std.debug.print("{any} {any}\n", .{ instance.world.blocks, instance.cart.slowdown });
        var previous_detector_rail_state = false;
        var previous_zero_time: ?usize = null;
        for (0..1000) |i| {
            instance.tickBlockTicks();
            if (instance.world.detector_rail_powered != previous_detector_rail_state) {
                if (previous_detector_rail_state) {
                    previous_zero_time = i;
                }
                previous_detector_rail_state = instance.world.detector_rail_powered;
            }
            instance.tickCart();
            if (instance.world.detector_rail_powered != previous_detector_rail_state) {
                if (previous_detector_rail_state) {
                    previous_zero_time = i;
                }
                previous_detector_rail_state = instance.world.detector_rail_powered;
            }
        }
        for (1000..72000000) |i| {
            instance.tickBlockTicks();
            // if (instance.world.detector_rail_powered != previous_detector_rail_state) {
            //     // std.debug.print("{any} {any}\n", .{i - previous_switch_time, previous_detector_rail_state});
            //     // std.debug.print("{d}\t{any}\t{any}\n", .{i, instance.cart.position, instance.cart.velocity});
            //     if (previous_detector_rail_state) {
            //         // std.debug.print("{any} {any}\n", .{instance.cart.position, instance.world.detector_rail_timer});
            //         if (previous_zero_time) |previous_zero_time_| {
            //             // _ = previous_zero_time_;
            //             std.debug.print("Interval: {d}\n", .{i - previous_zero_time_});
            //             return;
            //         }
            //         previous_zero_time = i;
            //     }
            //     previous_detector_rail_state = instance.world.detector_rail_powered;
            // }
            // std.debug.print("{d}\t{any}\t{any}\t{any}\n", .{i, instance.cart.position, instance.cart.velocity, instance.world.detector_rail_powered });
            // std.debug.print("{any}\n", .{instance.world.detector_rail_timer});
            instance.tickCart();
            if (instance.world.detector_rail_powered != previous_detector_rail_state) {
                // std.debug.print("{any} {any}\n", .{i - previous_switch_time, previous_detector_rail_state});
                // std.debug.print("{d}\t{any}\t{any}\n", .{i, instance.cart.position, instance.cart.velocity});
                if (previous_detector_rail_state) {
                    // std.debug.print("{any} {any}\n", .{instance.cart.position, instance.world.detector_rail_timer});
                    if (previous_zero_time) |previous_zero_time_| {
                        // _ = previous_zero_time_;
                        std.debug.print("Interval: {d}\n", .{i - previous_zero_time_});
                        return;
                    }
                    previous_zero_time = i;
                }
                previous_detector_rail_state = instance.world.detector_rail_powered;
            }
        }
        // std.debug.print("Timeout\n", .{});
    }
}

fn run_clocks() void {
    const detector_rail_set = cart_clock_simulation.Tags.detector_rails;
    const detector_wall_set = [_]cart_clock_simulation.Block{
        .chain,
        .lightning_rod,
        .flower_pot,
        .stone_brick_wall,
        .sea_pickle_2,
        .sea_pickle_3,
        .ender_chest,
        .white_stained_glass,
        .powder_snow,
        .cobweb,
        .honey_block,
    };
    const detector_extrusion_set = [_]cart_clock_simulation.Block{
        .air,
        .cherry_trapdoor_west,
        .medium_amethyst_bud,
        .large_amethyst_bud,
        .amethyst_cluster,
        .cherry_leaves,
        .honey_block,
    };
    const powered_rails_set = cart_clock_simulation.Tags.powered_rails;
    const powered_extrusion_set = [_]cart_clock_simulation.Block{
        .air,
        .cherry_trapdoor_east,
    };
    const powered_wall_set = [_]cart_clock_simulation.Block{.air} ++ detector_wall_set;

    const cart_slowdowns: [18]f64 = init: {
        comptime {
            var slowdowns: [18]f64 = undefined;
            slowdowns[0] = 0.96; // Empty cart
            slowdowns[1] = 0.9408; // Furnace cart
            for (slowdowns[2..], 0..) |*slowdown, i| {
                slowdown.* = 0.98 + (15 - @as(f64, i)) * 0.001;
            }
            break :init slowdowns;
        }
    };

    for (powered_rails_set) |powered_rail| {
        for (powered_wall_set) |powered_wall| {
            for (powered_extrusion_set) |powered_extrusion| {
                for (detector_rail_set) |detector_rail| {
                    for (detector_wall_set) |detector_wall| {
                        for (detector_extrusion_set) |detector_extrusion| {
                            for (cart_slowdowns) |slowdown| {
                                var instance: cart_clock_simulation.Instance = .{
                                    .world = .{
                                        .blocks = .{
                                            .{ .white_concrete, powered_wall },
                                            .{ powered_rail, powered_extrusion },
                                            .{ detector_rail, detector_extrusion },
                                            .{ .white_stained_glass, detector_wall },
                                        },
                                        .powered_rail_powered = true,
                                    },
                                    .cart = .{
                                        .position = .{ 1.49, 0.5 },
                                        .velocity = .{ 0.02, 0 },
                                        .slowdown = slowdown,
                                    },
                                };
                                run_clock(&instance);
                            }
                        }
                    }
                }
            }
        }
    }
}

fn test_one_clock() void {
    var instance: cart_clock_simulation.Instance = .{
        .world = .{
            .blocks = .{
                .{ .white_concrete, .air },
                .{ .powered_rail, .air },
                .{ .detector_rail, .cherry_leaves },
                .{ .white_stained_glass, .cobweb },
            },
            .powered_rail_powered = true,
        },
        .cart = .{
            .position = .{ 1.5, 0.5 },
            .velocity = .{ 0.02, 0 },
            .slowdown = 0.985,
        },
    };

    var previous_detector_rail_state = false;
    var previous_switch_time: usize = 0;
    var previous_zero_time: ?usize = null;
    for (0..100000) |i| {
        instance.tickBlockTicks();
        if (instance.world.detector_rail_powered != previous_detector_rail_state) {
            // std.debug.print("{any} {any}\n", .{ i - previous_switch_time, previous_detector_rail_state });
            // std.debug.print("{d}\t{any}\t{any}\n", .{ i, instance.cart.position, instance.cart.velocity });
            if (previous_detector_rail_state) {
                // std.debug.print("{any} {any}\n", .{ instance.cart.position, instance.world.detector_rail_timer });
                if (previous_zero_time) |previous_zero_time_| {
                    // _ = previous_zero_time_;
                    std.debug.print("Interval: {d}\n", .{i - previous_zero_time_});
                }
                previous_zero_time = i;
            }
            previous_detector_rail_state = instance.world.detector_rail_powered;
            previous_switch_time = i;
        }
        // if (instance.cart.position[0] == 1.49 and !instance.world.detector_rail_powered) {
        //     std.debug.print("{any}\n", .{i - previous_zero_time});
        //     previous_zero_time = i;
        // }
        // std.debug.print("{d}\t{any}\t{any}\t{any}\n", .{ i, instance.cart.position, instance.cart.velocity, instance.world.detector_rail_powered });
        // std.debug.print("{any}\n", .{instance.world.detector_rail_timer});
        instance.tickCart();
        if (instance.world.detector_rail_powered != previous_detector_rail_state) {
            // std.debug.print("{any} {any}\n", .{ i - previous_switch_time, previous_detector_rail_state });
            // std.debug.print("{d}\t{any}\t{any}\n", .{ i, instance.cart.position, instance.cart.velocity });
            if (previous_detector_rail_state) {
                // std.debug.print("{any} {any}\n", .{ instance.cart.position, instance.world.detector_rail_timer });
                if (previous_zero_time) |previous_zero_time_| {
                    _ = previous_zero_time_;
                    // std.debug.print("Interval: {d}\n", .{i - previous_zero_time_});
                }
                previous_zero_time = i;
            }
            previous_detector_rail_state = instance.world.detector_rail_powered;
            previous_switch_time = i;
        }
    }
    // std.debug.print("{any}", .{instance.cart.position});
}
