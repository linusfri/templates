{
  pkgs,
  lib,
  config,
  ...
}:
{
  processes.current-env.exec = ''
    devenv info
  '';
}
