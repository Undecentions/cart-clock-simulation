const std = @import("std");

pub const Block = enum {
    air,
    amethyst_cluster,
    chain,
    cherry_leaves,
    cherry_trapdoor_east,
    cherry_trapdoor_west,
    cobweb,
    detector_rail,
    detector_rail_waterlogged,
    ender_chest,
    flower_pot,
    honey_block,
    large_amethyst_bud,
    lightning_rod,
    medium_amethyst_bud,
    powder_snow,
    powered_rail,
    powered_rail_waterlogged,
    powered_rail_raised,
    powered_rail_raised_waterlogged,
    sea_pickle_2,
    sea_pickle_3,
    stone_brick_wall,
    white_concrete,
    white_stained_glass,
};

pub const Tags = struct {
    pub const powered_rails = [_]Block{
        .powered_rail,
        .powered_rail_raised,
        .powered_rail_raised_waterlogged,
        .powered_rail_waterlogged,
    };
    pub const detector_rails = [_]Block{
        .detector_rail,
        .detector_rail_waterlogged,
    };
    pub const rails = Tags.detector_rails ++ Tags.powered_rails;
};

// Not the best use of SIMD but whatever for now
const Vec2d = @Vector(2, f64);
const Vec2i = @Vector(2, i32);

const Direction = struct {
    const down: Vec2i = .{ 0, -1 };
    const up: Vec2i = .{ 0, 1 };
    const west: Vec2i = .{ -1, 0 };
    const east: Vec2i = .{ 1, 0 };
};

pub const Instance = struct {
    world: World,
    cart: Cart,

    pub fn tickBlockTicks(self: *Instance) void {
        if (self.world.detector_rail_timer) |*timer| {
            timer.* -= 1;
            if (timer.* <= 0) {
                self.world.detector_rail_timer = null;
                self.updateDetectorRailPoweredStatus();
            }
        }
    }

    pub fn tickCart(self: *Instance) void {
        self.tickCartController();
        // update cart water state
        for (@as(usize, @intFromFloat(@floor(self.cart.position[0] - Cart.width / 2.0 + 0.001)))..@as(usize, @intFromFloat(@ceil(self.cart.position[0] + Cart.width / 2.0 - 0.001)))) |x| {
            for (@as(usize, @intFromFloat(@floor(self.cart.position[1] + 0.001)))..@as(usize, @intFromFloat(@ceil(self.cart.position[1] + Cart.height - 0.001)))) |y| {
                const block = self.world.blocks[x][y];
                if (block == .powered_rail_waterlogged or block == .detector_rail_waterlogged or block == .cherry_leaves) {
                    self.cart.touchingWater = true;
                    return;
                }
            }
        }
        self.cart.touchingWater = false;
    }

    fn tickCartController(self: *Instance) void {
        // self.applyCartGravity();
        // const cart_pos: Block = self.getCartRailPos();
        // move on rail (pretty sure it never moves off-rail)
        self.moveCartOnRail();
        self.tickCartBlockCollision();
        // calculate and set pitch + yaw, not sure if this is ever used so might be noop
        // handle collision, no other entities push cart so noop
    }

    fn applyCartGravity(self: *Instance) void {
        self.cart.velocity[1] -= if (self.cart.touchingWater) 0.005 else 0.04;
    }

    fn getCartRailPos(self: *Instance) Vec2i {
        var block_pos = @as(Vec2i, @intFromFloat(@floor(self.cart.position)));
        if (block_pos[1] > 0 and self.world.isInTag(block_pos + Direction.down, @as([]const Block, &Tags.rails))) {
            block_pos += Direction.down;
        }
        return block_pos;
    }

    fn moveCartOnRail(self: *Instance) void {
        const cart_block_pos = self.getCartRailPos();
        const block = self.world.blocks[@as(usize, @intCast(cart_block_pos[0]))][@as(usize, @intCast(cart_block_pos[1]))];
        // self.cart.fallDistance = 0; // TODO declare fallDistance if needed, otherwise remove
        // This snap position is not actually used for snapping, it's used for the sloping movement gravity things
        const first_reference_snap_y_pos = self.calculateCartSnapYPos(self.cart.position);

        // Apply velocity based on slope of rail, and if it is on a slope, set the snap position up 1.
        // This means that the first y snap of a cart on a sloped rail is 1 above where it is supposed to be.
        var snap_y = cart_block_pos[1];

        // Game calculates if the cart is on a powered rail, and if that rail is powered.
        // This is omitted and calculated on-spot later instead for clarity.

        // Game had a switch with 4 cases for the directions property of a sloping rail,
        // but in this simulation blocks don't have states, as all are tied with the block itself.
        // After that, the game checks the shape of the rail and aligns the velocity of the cart
        // to the direction where the rail is going. ADJACENT_RAIL_POSITIONS_BY_SHAPE was a hashmap in the game code,
        // but there's not many rail shapes here anyways, so it just gets combined into the switch from above.
        // Now, the thing is actually pointless in here (it's 2D, aligning X to X is just noop), but the rail direction thing is used later.
        const sloped_rail_velocity_increment: f64 = if (self.cart.touchingWater) 1.0 / 640.0 else 1.0 / 128.0;
        const adjacent_rail_pos_first, const adjacent_rail_pos_second = switch (block) {
            // ASCENDING_EAST
            .detector_rail, .detector_rail_waterlogged => blk: {
                self.cart.velocity[0] -= sloped_rail_velocity_increment;
                snap_y += 1;
                break :blk .{ Direction.west + Direction.down, Direction.east };
            },
            // ASCENDING_WEST
            .powered_rail_raised, .powered_rail_raised_waterlogged => blk: {
                self.cart.velocity[0] += sloped_rail_velocity_increment;
                snap_y += 1;
                break :blk .{ Direction.west, Direction.east + Direction.down };
            },
            // EAST_WEST
            .powered_rail, .powered_rail_waterlogged => .{ Direction.west, Direction.east },
            else => unreachable,
        };

        // Game handles player input to the cart, which is noop

        // Handle if the cart is on an unpowered powered rail
        if (!self.world.powered_rail_powered) {
            if (@reduce(.Add, self.cart.velocity * self.cart.velocity) < 0.03 * 0.03) {
                self.cart.velocity = .{ 0, 0 };
            } else {
                self.cart.velocity[0] *= 0.5;
            }
        }

        // Game snaps the cart based on rail shape for x and z, and y from the logic above.
        // In 2D with rails parallel to the plane it's always snapped fine, so this is noop, other than setting y.
        self.cart.position[1] = @floatFromInt(snap_y);
        // Game move()s the minecart with MovementType.SELF and speed clamped velocity.
        // Game does check passengers but this assumes that cart is passenger-less.
        const speed_limit: f64 = if (self.cart.slowdown == 0.9408) (if (self.cart.touchingWater) 0.2 * 0.75 else 0.4 * 0.5) else (if (self.cart.touchingWater) 0.2 else 0.4);
        self.moveCart(Vec2d{ std.math.clamp(self.cart.velocity[0], -speed_limit, speed_limit), 0 });
        // Then the game snaps the cart vertically if the cart moved out of the current rail block into an adjacent one.
        if (adjacent_rail_pos_first[1] != 0 and @as(i32, @intFromFloat(@floor(self.cart.position[0]))) - cart_block_pos[0] == adjacent_rail_pos_first[0]) {
            self.cart.position[1] += @floatFromInt(adjacent_rail_pos_first[1]);
        } else if (adjacent_rail_pos_second[1] != 0 and @as(i32, @intFromFloat(@floor(self.cart.position[0]))) - cart_block_pos[0] == adjacent_rail_pos_second[0]) {
            self.cart.position[1] += @floatFromInt(adjacent_rail_pos_second[1]);
        }

        // Apply slowdown to motion
        self.cart.velocity[0] *= self.cart.slowdown;
        if (self.cart.touchingWater) {
            self.cart.velocity *= @splat(0.95);
        }

        const second_reference_snap_y_pos = self.calculateCartSnapYPos(self.cart.position);
        // std.debug.print("{any} {any}\n", .{first_reference_snap_y_pos, second_reference_snap_y_pos});
        if (first_reference_snap_y_pos) |first_reference_snap_y_pos_| {
            if (second_reference_snap_y_pos) |second_reference_snap_y_pos_| {
                // Scale velocity by difference of the 2 y snap positions
                // as a proportion of horizontal velocity, then snap y.
                // Here, horizontal length is just x since 2D.
                const velocity_horizontal_length = @abs(self.cart.velocity[0]);
                if (velocity_horizontal_length > 0) {
                    self.cart.velocity[0] *= (velocity_horizontal_length + (first_reference_snap_y_pos_ - second_reference_snap_y_pos_) * 0.05) / velocity_horizontal_length;
                }
                self.cart.position[1] = second_reference_snap_y_pos_;
            }
        }

        // Game checks if cart moved out of the block and change direction of velocity based off that.
        // Preserves velocity on turns, but there's no turns in this simulation, so this is noop.

        // Powered rail logic
        if (self.world.isInTag(cart_block_pos, @as([]const Block, &Tags.powered_rails))) {
            // If velocity over 0.01 horizontally, add 0.06 of normalized velocity,
            // or acceleration at 0.06 in motion direction. Motion direction is always
            // along the x axis, so it's just 0.06 acceleration.
            // Otherwise, check if there is a solid block adjacent and accelerate cart off if found.
            if (self.cart.velocity[0] > 0.01) {
                self.cart.velocity[0] += 0.06;
            } else if (self.cart.velocity[0] < -0.01) {
                self.cart.velocity[0] -= 0.06;
            } else {
                // Game checks to accelerate off a solid block, but in this case the only powered rail
                // only has a solid block on the west side and that would be white_concrete.
                if (self.cart.position[0] > 0 and self.world.blocks[@as(usize, @intFromFloat(@floor(self.cart.position[0]))) - 1][@as(usize, @intFromFloat(@floor(self.cart.position[1])))] == .white_concrete) {
                    self.cart.velocity[0] = 0.02;
                }
            }
        }
    }

    fn calculateCartSnapYPos(self: *const Instance, cart_pos: Vec2d) ?f64 {
        var cart_block_pos = @as(Vec2i, @intFromFloat(@floor(cart_pos)));
        if (cart_block_pos[1] > 0 and self.world.isInTag(cart_block_pos + Direction.down, @as([]const Block, &Tags.rails))) {
            cart_block_pos += Direction.down;
        }
        const block = self.world.blocks[@as(usize, @intCast(cart_block_pos[0]))][@as(usize, @intCast(cart_block_pos[1]))];
        if (self.world.isInTag(cart_block_pos, @as([]const Block, &Tags.rails))) {
            // ADJACENT_RAIL_POSITIONS_BY_SHAPE again, represented as a switch case, but directions replace with y-values.
            const adjacent_rail_y_first: i32, const adjacent_rail_y_second: i32 = switch (block) {
                // ASCENDING_EAST
                .detector_rail, .detector_rail_waterlogged => .{ -1, 0 },
                // ASCENDING_WEST
                .powered_rail_raised, .powered_rail_raised_waterlogged => .{ 0, -1 },
                // EAST_WEST
                .powered_rail, .powered_rail_waterlogged => .{ 0, 0 },
                else => unreachable,
            };
            const adjacent_pos_y_difference = adjacent_rail_y_second - adjacent_rail_y_first;
            // Game snaps the cart, except z snap is nonexistent (2D),
            // x snap is noop (all rails used are parallel to plane),
            // so only y snap exists.
            var snap_y = @as(f64, @floatFromInt(cart_block_pos[1])) + 1.0 / 16.0 + @as(f64, @floatFromInt(adjacent_pos_y_difference)) * (cart_pos[0] - @as(f64, @floatFromInt(cart_block_pos[0])));
            if (adjacent_pos_y_difference < 0) {
                snap_y += 1;
            }
            return snap_y;
        }
        return null;
    }

    fn moveCart(self: *Instance, movement_: Vec2d) void {
        var movement = movement_;
        // Game checks no-clip logic, noop
        // Game checks piston movement, noop

        // Movement multiplier logic
        if (@reduce(.Add, self.cart.movementMultiplier * self.cart.movementMultiplier) > 1.0E-7) {
            movement *= self.cart.movementMultiplier;
            self.cart.movementMultiplier = .{ 0, 0 };
            self.cart.velocity = .{ 0, 0 };
        }

        // Game checks sneaking, noop

        const collision_adjusted_movement = self.adjustCartMovementForCollisions(movement); // TODO
        // std.debug.print("-{any}, {any}\n", .{ movement, collision_adjusted_movement });
        const collision_adjusted_movement_magnitude_squared = @reduce(.Add, collision_adjusted_movement * collision_adjusted_movement);
        const movement_magnitude_squared = @reduce(.Add, movement * movement);
        if (collision_adjusted_movement_magnitude_squared > 1.0E-7 or movement_magnitude_squared - collision_adjusted_movement_magnitude_squared < 1.0E-7) {
            // fall damage raycast (probably noop here, add if fallDistance is useful)
            // queue some collision checks TODO might be noop
            self.cart.position += collision_adjusted_movement;
        }

        const horizontal_collision = !std.math.approxEqAbs(f64, movement[0], collision_adjusted_movement[0], 1.0E-5);
        // const verticalCollision = movement[1] != collision_adjusted_movement[1];
        // const groundCollision = verticalCollision and movement[1] < 0.0;
        // self.setCartMovement(groundCollision, horizontalCollision, collision_adjusted_movement); // noop maybe

        // Game sets collidedSoftly, unused so noop

        // TODO consider onground
        // self.cartFall(collision_adjusted_movement[1], self.cart.position + Vec2d{ 0, -0.2 }); // noop maybe

        // Game checks this.isRemoved() to halt, cart never dies so noop

        if (horizontal_collision) self.cart.velocity[0] = 0;

        // self.applyCartMoveEffect(); // .EVENTS noop maybe

        // scale velocity by velocitymultiplier
        // assumes the cart is on a rail, which has velocity multiplier set to 1, noop
        // TODO figure out why honey blocks work if ^ is true, maybe clip up one block on slope
        const block_pos = @as(@Vector(2, usize), @intFromFloat(@floor(self.cart.position)));
        if (self.world.blocks[block_pos[0]][block_pos[1]] == .honey_block) {
            self.cart.velocity[0] *= 0.4;
        }
        self.tickCartBlockCollision();
    }

    fn adjustCartMovementForCollisions(self: *Instance, movement: Vec2d) Vec2d {
        // All entity collision logic is noop
        if (@reduce(.And, movement == Vec2d{ 0, 0 })) return movement;
        var collisions: [2]?f64 = undefined;
        if (movement[0] > 0) {
            collisions = .{
                switch (self.world.blocks[2][1]) {
                    .cherry_trapdoor_west => 13,
                    .medium_amethyst_bud => 12,
                    .large_amethyst_bud => 11,
                    .amethyst_cluster => 9,
                    else => null,
                },
                switch (self.world.blocks[3][1]) {
                    .chain => 8 - 3.0 / 2.0,
                    .lightning_rod => 6,
                    .flower_pot => 5,
                    .stone_brick_wall => 4,
                    .sea_pickle_2 => 3,
                    .sea_pickle_3 => 2,
                    .ender_chest, .honey_block => 1,
                    .white_stained_glass => 0,
                    else => null,
                },
            };
            if (collisions[0]) |*collision| {
                collision.* = collision.* / 16 + 2;
            }
            if (collisions[1]) |*collision| {
                collision.* = collision.* / 16 + 3;
            }
        } else if (self.world.blocks[1][0] == .powered_rail_raised and self.world.blocks[1][0] == .powered_rail_raised_waterlogged) {
            collisions = .{
                switch (self.world.blocks[1][1]) {
                    .cherry_trapdoor_east => 3,
                    else => null,
                },
                switch (self.world.blocks[0][1]) {
                    .chain => 8 + 3 / 2,
                    .lightning_rod => 10,
                    .flower_pot => 11,
                    .stone_brick_wall => 12,
                    .sea_pickle_2 => 13,
                    .sea_pickle_3 => 14,
                    .ender_chest, .honey_block => 15,
                    .white_stained_glass => 16,
                    else => null,
                },
            };
            if (collisions[0]) |*collision| {
                collision.* = collision.* / 16 + 1;
            }
            if (collisions[1]) |*collision| {
                collision.* /= 16;
            }
        } else {
            collisions = .{ 1, 1 };
        }

        for (collisions) |optional_collision| {
            if (optional_collision) |collision| {
                const max_distance = collision - (if (movement[0] < 0) self.cart.position[0] - Cart.width / 2.0 else self.cart.position[0] + Cart.width / 2.0);
                if (@abs(max_distance) >= 1.0E-7 and @abs(max_distance) <= @abs(movement[0])) {
                    return .{ max_distance, movement[1] };
                }
                return movement;
            }
        }

        return movement;
    }

    fn tickCartBlockCollision(self: *Instance) void {
        // Game does onground stepon logic, if cart is never off a rail or blocks don't have onSteppedOn this is noop TODO

        // checkBlockCollisions:
        for (@as(usize, @intFromFloat(@floor(self.cart.position[0] - Cart.width / 2.0 + 1.0E-5)))..@as(usize, @intFromFloat(@ceil(self.cart.position[0] + Cart.width / 2.0 - 1.0E-5)))) |x| {
            for (@as(usize, @intFromFloat(@floor(self.cart.position[1] + 1.0E-5)))..@as(usize, @intFromFloat(@ceil(self.cart.position[1] + Cart.height - 1.0E-5)))) |y| {
                // Game checks this.isAlive to halt, cart never dies so noop
                const block = self.world.blocks[x][y];
                // if air run afterCollisionCheck (noop)
                // else if collidedBlockPositions.add is false (already present in set) (noop)
                // else
                // Game does block collision logic, represented by a switch, with noop logic removed
                // Game does other noop collision handler stuff
                switch (block) {
                    .detector_rail, .detector_rail_waterlogged => if (!self.world.detector_rail_powered) self.updateDetectorRailPoweredStatus(),
                    .cobweb => self.cart.movementMultiplier = .{ 0.25, 0.05 },
                    .powder_snow => self.cart.movementMultiplier = .{ 0.9, 1.5 },
                    else => {},
                }
                // Game does fluid collision logic, but noop since water extinguishes and lava ignites
            }
        }

        // collisionHandler runCallbacks probably noop
        // Game does burning logic, noop
        // clearQueuedCollisionChecks might be noop
    }

    fn updateDetectorRailPoweredStatus(self: *Instance) void {
        const shouldPower = self.cart.position[0] + Cart.width / 2.0 > 2.2 and self.cart.position[0] - Cart.width / 2.0 < 2.8 and self.cart.position[1] < 0.8;
        self.world.detector_rail_powered = shouldPower;
        if (shouldPower) self.world.detector_rail_timer = 20;
    }
};

const Cart = struct {
    const width: f64 = 0.98;
    const height: f64 = 0.7;
    position: Vec2d,
    velocity: Vec2d = .{ 0, 0 },
    slowdown: f64,
    movementMultiplier: Vec2d = .{ 0, 0 },
    touchingWater: bool = false,
};

const World = struct {
    blocks: [4][2]Block,
    powered_rail_powered: bool, // No block states in this simulation so this gets stored here
    detector_rail_powered: bool = false,
    detector_rail_timer: ?u8 = null, // Figure out the best int size later

    fn isInTag(self: *const World, pos: Vec2i, tag: []const Block) bool {
        const pos_ = @as(@Vector(2, usize), @intCast(pos));
        return std.mem.findScalar(Block, tag, self.blocks[pos_[0]][pos_[1]]) != null;
    }
};
