{ self
, inputs
, lib
, ...
}:
let
  inherit (lib) nixosSystem cartesianProduct;
  inherit (self.lib) genAttrs' listNixName;
  x86_64-hosts = cartesianProduct {
    name = listNixName ./x86_64-linux;
    system = [ "x86_64-linux" ];
  };
  aarch64-hosts = cartesianProduct {
    name = listNixName ./aarch64-linux;
    system = [ "aarch64-linux" ];
  };
  hosts = x86_64-hosts ++ aarch64-hosts;
in
{
  flake = {
    nixosConfigurations = genAttrs' hosts (
      host:
      (nixosSystem {
        inherit (host) system;
        specialArgs = {
          inherit inputs self;
          pkgs-self = self.legacyPackages.${host.system};
        };
        modules = [
          "${self}/hosts/${host.system}/${host.name}.nix"
          self.nixosModules.default
          inputs.colmena.nixosModules.deploymentOptions
        ];
      })
    );
    colmena =
      (genAttrs' hosts (host: {
        imports = [
          # SSH to llmnr hosts need retry to wait for hostname resolution.
          # Requires colmena version > 0.5.0.
          # { deployment.sshOptions = [ "-o" "ConnectionAttempts=2" ]; }
          "${self}/hosts/${host.system}/${host.name}.nix"
          self.nixosModules.default
        ];
      }))
      // {
        meta = {
          nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
          machinesFile = "/etc/nix/machines";
          nodeNixpkgs = genAttrs' hosts
            (host: (import inputs.nixpkgs { inherit (host) system; }));
          nodeSpecialArgs = genAttrs' hosts
            (host: { inherit inputs self; pkgs-self = self.legacyPackages.${host.system}; });
        };
      };
  };
}
