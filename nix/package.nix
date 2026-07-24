{
  lib,
  stdenv,
  zig_0_16,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "cart-clock-simulation";
  version = "0-unstable-2026-07-23";

  src = ../.;

  nativeBuildInputs = [
    zig_0_16.hook
  ];

  zigBuildFlags = [ "-Doptimize=ReleaseFast" ];

  meta = {
    description = "Simulates cart clocks";
    homepage = "https://github.com/Undecentions/cart-clock-simulation";
    license = lib.licenses.mit;
    # maintainers = with lib.maintainers; [ ];
    mainProgram = "cart_clock_simulation";
    inherit (zig_0_16.meta) platforms;
  };
})
