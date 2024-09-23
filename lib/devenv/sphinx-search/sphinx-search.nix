{ pkgs, lib, config, ... }:
let
  inherit (lib) mkOption types;
  inherit (pkgs) stdenv;

  sphinxPkg = pkgs.sphinxsearch;
  cfg = config.services.linusfri.sphinxsearch;

  sphinxsearch = stdenv.mkDerivation rec {
    pname = "sphinxsearch";
    version = "2.2.11";
    dontUnpack = true;
    src = ./.;

    nativeBuildInputs = [ sphinxPkg ];

    configurePhase = ''
      # Sphinx Client
      export SPHINX_SERVER_PORT="${toString cfg.port}"
      export SPHINX_SERVER="${cfg.host}"
      export SPHINX_DB="${cfg.dbName}"

      # Sphinx Server
      export SPHINX_DB_HOST="${cfg.dbHost}"
      export SPHINX_DB_USER="${cfg.dbUser}"
      export SPHINX_DB_PASS="${cfg.dbPass}"
      export SPHINX_DB_PORT="${toString cfg.dbPort}"
      export SPHINX_DB_NAMES="${cfg.dbNames}"
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out $out/etc
      source ${src}/config.sh > sphinx.conf
      cp sphinx.conf $out/etc

      cp -r ${sphinxPkg}/* $out/
      runHook postInstall
    '';
  };
in
{
  options.services.linusfri.sphinxsearch = {
    enable = lib.mkEnableOption "Enable Sphinx search for dev environment.";

    port = mkOption {
      type = types.port;
      default = 9312;
      description = "Port for the Sphinx search daemon.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host for the Sphinx search daemon.";
    };

    dbName = mkOption {
      type = types.str;
      default = "site";
      description = "Name of the database for Sphinx search.";
    };

    dbHost = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host for the MySQL database.";
    };

    dbUser = mkOption {
      type = types.str;
      default = "admin";
      description = "Username for connecting to the MySQL database.";
    };

    dbPass = mkOption {
      type = types.str;
      default = "1234";
      description = "Password for connecting to the MySQL database.";
    };

    dbPort = mkOption {
      type = types.port;
      default = 3306;
      description = "Port for connecting to the MySQL database.";
    };

    dbNames = mkOption {
      type = types.str;
      default = "";
      description = "Database names and their configurations for Sphinx search.";
    };
  };

  config = lib.mkIf cfg.enable {
    env = {
      # Sphinx Client
      SPHINX_SERVER_PORT = "${toString cfg.port}";
      SPHINX_SERVER = "${cfg.host}";
      SPHINX_DB = "${cfg.dbName}";

      # Sphinx Server
      SPHINX_DB_HOST = "${cfg.dbHost}";
      SPHINX_DB_USER = "${cfg.dbUser}";
      SPHINX_DB_PASS = "${cfg.dbPass}";
      SPHINX_DB_PORT = "${toString cfg.dbPort}";
      SPHINX_DB_NAMES = "${cfg.dbNames}";
    };

    processes.sphinxsearch.exec = "${sphinxsearch}/bin/sphinxsearch-searchd";
    scripts.sphinxPath.exec = "echo ${sphinxsearch}";
  };
}