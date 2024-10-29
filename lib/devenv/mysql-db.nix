{ pkgs, lib, config, ... }:
let
  cfg = config.services.linusfri.mysql;

  additionalDatabases = map (dbName:
    { name = dbName; }
  ) cfg.additionalDbNames;

  additionalPermissions = builtins.listToAttrs (map (dbName: { name = "${dbName}.*"; value = "ALL PRIVILEGES"; }) cfg.additionalDbNames);

  # If user has exported custom env variable for db name in local environment
  dbName = if builtins.hasAttr "DEV_DB_NAME_OVERRIDE" config.env then config.env.DEV_DB_NAME_OVERRIDE else cfg.dbName;
in {
  imports = [ ./common.nix ];

  options = {
    services.linusfri.mysql = {
      enable = lib.mkEnableOption "Enable MySQL.";

      package = lib.mkOption {
        type = lib.types.package;
        description = "Package to use for database server (MySQL or MariaDB)";
        default = pkgs.mysql84;
        example = pkgs.mariadb;
      };

      host = lib.mkOption {
        type = lib.types.str;
        description = "Database listening adress";
        default = "127.0.0.1";
      };

      port = lib.mkOption {
        type = lib.types.port;
        description = "Database listening port.";
        default = 3306;
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

      dbName = lib.mkOption {
        type = lib.types.str;
        description = "Project database name.";
        default = "default";
      };

      additionalDbNames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Additional names of databases to create.";
        default = [];
      };

      tablePrefix = lib.mkOption {
        type = lib.types.str;
        description = "Project table prefix.";
        default = "wp_";
      };
      
      settings = lib.mkOption {
        type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.anything);
        default = {
          mysqld = {
            port = cfg.port;
            log_bin_trust_function_creators = 1;
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    env = {
      DB_HOST = "${cfg.host}:${toString cfg.port}";
      DB_PORT = toString cfg.port;
      DB_USER = cfg.user;
      DB_PASSWORD = cfg.password;
      DB_NAME = dbName;
      DB_PREFIX = cfg.tablePrefix;
    };

    packages = [ cfg.package ];

    services.mysql = {
      enable = lib.mkDefault true;

      package = cfg.package;

      initialDatabases = [
        { name = dbName; }
      ] ++ additionalDatabases;
      settings = cfg.settings;
      ensureUsers = lib.mkDefault [
        {
          name = cfg.user;
          password = cfg.password;
          ensurePermissions = {
            "${dbName}.*" = "ALL PRIVILEGES";
          } // additionalPermissions;
        }
      ];
    };

    scripts.mysql-local.exec = "mysql -u '${cfg.user}' --password='${cfg.password}' -h '${cfg.host}' '${dbName}' \"$@\"";
  };
}
