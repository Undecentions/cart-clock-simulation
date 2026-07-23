# cart-clock-simulation
Simulates [cart clocks](https://youtu.be/_h6YhcDutTg).

## Building from source
Currently the simulation does not distribute binaries (see Usage). Fortunately, compiling from source is simple.
Ensure Zig is installed, then run `zig build`. Use `-Doptimize=` to control optimization level. The output will be in `zig-out/bin/`.

## Usage
Currently the simulation does not take any parameters from the command line. Instead, all configuration is done in the code before compiling and executing it.
Most of the configuration is self-explanatory though all over the place. Note that for cart slowdown, empty cart is `0.96`, furnace cart is `0.9408`, and chest cart is `0.98 + 0.001 * (15 - ss)` where `ss` is the cart fill level.
