{
  self,
  inputs,
  lib,
  ...
}:
let
  x86_64-hosts = lib.filesystem.listFilesRecursive ./x86_64-linux;
  aarch64-hosts = lib.filesystem.listFilesRecursive ./aarch64-linux;
  all-hosts = lib.listToAttrs (
    map (
      path:
      let
        system = baseNameOf (dirOf path);
        name = lib.removeSuffix ".nix" (baseNameOf path);
      in
      lib.nameValuePair name { inherit path system; }
    ) (x86_64-hosts ++ aarch64-hosts)
  );
in
{
  flake = {
    nixosConfigurations = lib.mapAttrs (
      n: v:
      lib.nixosSystem {
        inherit (v) system;
        specialArgs = {
          inherit inputs self;
          pkgs-self = self.legacyPackages.${v.system};
        };
        modules = [
          v.path
          self.nixosModules.default
          inputs.colmena.nixosModules.deploymentOptions
        ];
      }
    ) all-hosts;
    colmena =
      (lib.mapAttrs (n: v: {
        imports = [
          # SSH to llmnr hosts need retry to wait for hostname resolution.
          # Requires colmena version > 0.5.0.
          # { deployment.sshOptions = [ "-o" "ConnectionAttempts=2" ]; }
          v.path
          self.nixosModules.default
        ];
      }) all-hosts)
      // {
        meta = {
          nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
          machinesFile = "/etc/nix/machines";
          nodeNixpkgs = lib.mapAttrs (n: v: (import inputs.nixpkgs { inherit (v) system; })) all-hosts;
          nodeSpecialArgs = lib.mapAttrs (n: v: {
            inherit inputs self;
            pkgs-self = self.legacyPackages.${v.system};
          }) all-hosts;
        };
      };
  };
}
