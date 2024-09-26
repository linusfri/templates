{ pkgs, lib, config, ... }:
{
  options = {
    containerDeps = lib.mkOption {
      type = lib.types.package;
      description = "Dependencies for container builds.";
      default = [];
    };
  };
}
