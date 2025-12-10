{ self, inputs, ... }:
{
  nixpkgs.overlays = [
    (inputs.nixos-images.overlays.default or self.overlays.default or (final: prev: { }))
  ];
}
