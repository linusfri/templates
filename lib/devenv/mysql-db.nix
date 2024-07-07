{ pkgs, lib, config, ... }:
let
  cfg = config.services.linusfri.mysql;
in
{
  options.services.linusfri.mysql = {
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
      default = "db";
    };

    protocol = lib.mkOption {
      type = lib.types.str;
      description = "Mysql connection protocol";
      default = "mysql";
    };
  };

  config = {
    env = {
      DB_CONNECTION_STRING="${cfg.protocol}://${cfg.user}:${cfg.password}@${cfg.host}:${toString cfg.port}/${cfg.dbName}";
      DATABASE_URL="${cfg.protocol}://${cfg.user}:${cfg.password}@${cfg.host}:${toString cfg.port}/${cfg.dbName}"; # REQUIRED FOR SQLX
    };

    services.mysql = {
      enable = true;
      package = pkgs.mysql80;
      initialDatabases = lib.mkDefault [
        { name = cfg.dbName; }
        # { name = mysql_test_database; }
      ];
      settings.mysql.port = cfg.port;
      settings.mysqld.log_bin_trust_function_creators = 1;
      ensureUsers = lib.mkDefault [
        {
          name = cfg.user;
          password = cfg.password;
          ensurePermissions = {
            "${cfg.dbName}.*" = "ALL PRIVILEGES";
            # "${mysql_test_database}.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    scripts.mysql-local.exec = "mysql -u '${cfg.user}' --password='${cfg.password}' -h '${cfg.host}' '${cfg.dbName}' \"$@\"";
    scripts.sqlxmigrate.exec = "sqlx migrate run";
  };
}
