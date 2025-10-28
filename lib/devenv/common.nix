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

  scripts = {
    get-network-host = {
      exec = ''
        ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p'

        if [[ $? -ne 0 ]]; then
          echo "Failed to get development network host."
          exit 1
        fi
      '';
      packages = with pkgs; [ gnused ];
    };
  };
}
