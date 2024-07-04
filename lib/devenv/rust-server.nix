{ pkgs, lib, config, ... }:
let
  cfg = config.services.linusfri.rustServer;

  numberOfHosts = builtins.length cfg.domains;
  mainDomain = if numberOfHosts > 0 then builtins.elemAt cfg.domains 0 else "localhost";

  certificateName = if numberOfHosts < 2 then mainDomain else "${mainDomain}+${builtins.toString (numberOfHosts - 1)}";
  serverName = lib.strings.concatMapStringsSep " " (domain: domain) cfg.domains;
in
{
  options.services.linusfri.rustServer = {
    enable = lib.mkEnableOption "Enable rust base server.";

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of domains to add to /etc/hosts and generate certificates for.";
      default = [];
    };

    mainDomain = lib.mkOption {
      type = lib.types.str;
      description = "Main domain.";
      default = mainDomain;
    };

    appPort = lib.mkOption {
      type = lib.types.port;
      description = "Port where the app serves its content.";
      default = 8080;
    };

    sslPort = lib.mkOption {
      type = lib.types.port;
      description = "NGINX listen port for HTTPS.";
      default = 4430;
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "NGINX listen port for HTTPS.";
      default = 8000;
    };

    host = lib.mkOption {
      type = lib.types.str;
      description = "The host which the server runs on";
      default = "127.0.0.1";
    };

    serveDirRoot = lib.mkOption {
      type = lib.types.str;
      description = "Path from where the webserver will serve files.";
      default = "src";
    };
  };

  config = lib.mkIf cfg.enable {
    certificates = cfg.domains;
    hosts = builtins.listToAttrs (map (domain: { name = domain; value = "127.0.0.1"; }) cfg.domains);

    env = {
      ADDRESS_AND_PORT="${cfg.host}:${toString cfg.appPort}"; # For rust app to listen on
    };

    services.nginx = {
      enable = lib.mkDefault true;
      httpConfig = lib.mkDefault ''
        server {
          listen ${toString cfg.port};
          listen ${toString cfg.sslPort} ssl;
          ssl_certificate     ${config.env.DEVENV_STATE}/mkcert/${certificateName}.pem;
          ssl_certificate_key ${config.env.DEVENV_STATE}/mkcert/${certificateName}-key.pem;
          # ssl_protocols       TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
          # ssl_ciphers         HIGH:!aNULL:!MD5;

          root ${config.env.DEVENV_ROOT}/${cfg.serveDirRoot};
          index index.html index.htm;
          server_name ${serverName};

          error_page 497 https://$server_name:$server_port$request_uri;

          location / {
            proxy_pass "http://${cfg.host}:${toString cfg.appPort}";
          }
        }
      '';
    };
  };
}