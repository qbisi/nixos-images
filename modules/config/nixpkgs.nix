{ self, inputs, ... }:
{
  nixpkgs.overlays = [
    (self.overlays.default or (final: prev: { }))
    (inputs.nixos-images.overlays.default or (final: prev: { }))
  ];
}
