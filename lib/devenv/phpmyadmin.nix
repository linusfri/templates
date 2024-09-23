{ pkgs, lib, config, ... }:
let
  inherit (pkgs) unzip;
  inherit (lib) types;

  cfg = config.services.linusfri.phpmyadmin;

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
      runHook preInstall

      mkdir -p $out;

      echo '
        <?php
          $i = 0;
          $i++;

          $cfg["Servers"][$i] = [
            "host" => "${cfg.dbHost}",
            "port" => "${toString cfg.dbServerPort}",
            "user" => "${cfg.user}",
            "password" => "${cfg.password}"
          ];

      ' > config.inc.php;

      mv ./* $out/;

      runHook postInstall
    '';
  };
in
{
  options.services.linusfri.phpmyadmin = {
    enable = lib.mkEnableOption "Phpmyadmin process";

    host = lib.mkOption {
      type = types.str;
      description = "Host where phpmyadmin is running";
      default = "127.0.0.1";
    };

    dbHost = lib.mkOption {
      type = types.str;
      description = "Host where database server is running";
      default = "127.0.0.1";
    };

    dbServerPort = lib.mkOption {
      type = types.port;
      description = "Port which the database server uses.";
      default = 3306;
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Phpmyadmin listen port.";
      default = 9000;
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = "Database user.";
      default = "admin";
    };

    password = lib.mkOption {
      type = lib.types.str;
      description = "Database password.";
      default = "1234";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      description = "The port which phpmyadmin should listen on.";
      default = 9000;
    };
  };

  config = lib.mkIf cfg.enable {
    processes.phpmyadmin.exec = "${config.languages.php.package}/bin/php -S ${cfg.host}:${toString cfg.port} -t ${phpmyadmin}";
  };
}
