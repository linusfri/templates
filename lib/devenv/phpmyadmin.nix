{ pkgs, lib, config, ... }:
let
  inherit (pkgs) unzip;

  phpmyadmin = pkgs.stdenv.mkDerivation {
    name = "phpmyadmin";
    src = builtins.fetchurl {
      url = "https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip";
      sha256 = "0vlla5sg95f3hiq9svkl5wghdy3ca3znzb1ibndqj3qfq3jmzj9i";
    };

    nativeBuildInputs = [
      unzip
    ];

    installPhase = ''
      mkdir -p $out;
      cp -r ./ $out/src;
    '';
  };
  cfg = config.services.linusfri.phpmyadmin;
in
{

  options.services.linusfri.phpmyadmin = {
    enable = lib.mkEnableOption "Phpmyadmin process";
  };

  config = lib.mkIf cfg.enable {
    processes.phpmyadmin.exec = "${pkgs.php83}/bin/php -S localhost:8080 -t ${phpmyadmin}/src";
    scripts.getpath.exec = "echo ${phpmyadmin} > outpath";
  };
}