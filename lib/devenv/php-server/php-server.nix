{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.linusfri.phpServer;
in
{
  imports = [
    ./config/web-server.nix
  ];

  options.services.linusfri.phpServer = {
    enable = lib.mkEnableOption "Enable NGINX and PHP-FPM for dev environment.";

    serveDir = lib.mkOption {
      type = lib.types.str;
      description = "NGINX serve directory";
      default = "public";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "NGINX listen port.";
      default = 8080;
    };

    sslPort = lib.mkOption {
      type = lib.types.port;
      description = "NGINX listen port for HTTPS.";
      default = 4430;
    };

    https = lib.mkOption {
      type = lib.types.bool;
      description = "Enable or disable https";
      default = false;
    };

    appType = lib.mkOption {
      type = lib.types.enum [
        "default"
        "wordpress"
        "laravel"
      ];
      description = "Application type for correct server config.";
      default = null;
      example = ''default'';
    };

    php = lib.mkOption {
      type = lib.types.package;
      description = "PHP package to use.";
      default = pkgs.php;
    };

    ini = lib.mkOption {
      description = "PHP ini.";
      type = lib.types.str;
      default = ''
        memory_limit = 512M
        realpath_cache_ttl = 3600
        max_execution_time = 300
        post_max_size = 64M
        upload_max_filesize = 64M
        session.gc_probability = 0
        display_errors = On
        error_reporting = E_ALL
        log_errors = On
        error_log = ${config.env.DEVENV_STATE}/php_error
        zend.assertions = -1
        opcache.memory_consumption = 256M
        opcache.interned_strings_buffer = 20
        short_open_tag = 0
        zend.detect_unicode = 0
        realpath_cache_ttl = 3600
      '';
    };

    phpEnv = lib.mkOption {
      description = "PHP environment, overrides both `php` and `ini` if set.";
      type = lib.types.package;
      default = cfg.php.buildEnv {
        # extension = { all, enabled }: builtins.attrValues all;
        extraConfig = ''
          memory_limit = 512M
          realpath_cache_ttl = 3600
          max_execution_time = 300
          post_max_size = 64M
          upload_max_filesize = 64M
          session.gc_probability = 0
          display_errors = On
          error_reporting = E_ALL
          log_errors = On
          error_log = ${config.env.DEVENV_STATE}/php_error
          zend.assertions = -1
          opcache.memory_consumption = 256M
          opcache.interned_strings_buffer = 20
          short_open_tag = 0
          zend.detect_unicode = 0
          realpath_cache_ttl = 3600
        '';
      };
    };

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of domains to add to /etc/hosts and generate certificats for.";
      default = [ ];
    };

    mainDomain = lib.mkOption {
      type = lib.types.str;
      description = "Main domain.";
      default = cfg.commonServerConfig.mainDomain;
    };

    assetFallbackUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Asset fallback URL to redirect to for missing assets.";
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    env = if cfg.appType == "default" then cfg.envConfig.wordpress else cfg.envConfig.${cfg.appType};

    packages = [ ];

    services.nginx = {
      enable = lib.mkDefault true;
      httpConfig = lib.mkDefault ''
        server {
          listen ${toString cfg.port};
          listen ${toString cfg.sslPort} ssl;
          ssl_certificate     ${config.env.SSL_CERT};
          ssl_certificate_key ${config.env.SSL_CERT_KEY};
          # ssl_protocols       TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
          # ssl_ciphers         HIGH:!aNULL:!MD5;

          root ${config.env.DEVENV_ROOT}/${cfg.serveDir};
          index index.php index.html index.htm;
          server_name ${cfg.commonServerConfig.serverName};

          error_page 497 https://$server_name:$server_port$request_uri;
          client_max_body_size 64m;

          ${if cfg.appType == "default" then cfg.nginxConfig.wordpress else cfg.nginxConfig.${cfg.appType}}

          ${
            if cfg.assetFallbackUrl != null then
              ''
                # Caches images, icons, video, audio, HTC, etc.
                location ~* \.(?:jpg|jpeg|gif|pdf|png|webp|ico|cur|gz|svg|mp4|mp3|ogg|ogv|webm|htc)$ {
                    expires 1y;
                    access_log off;
                    add_header Access-Control-Allow-Origin *;
                    try_files $uri @production;
                }

                location @production {
                  resolver 8.8.8.8;
                  proxy_ssl_server_name on;
                  proxy_pass ${cfg.assetFallbackUrl};
                }
              ''
            else
              ""
          }
        }
      '';
    };

    processes = {
      php_error.exec = "touch ${config.env.DEVENV_STATE}/php_error; tail -f ${config.env.DEVENV_STATE}/php_error";
    };

    certificates = cfg.domains;
    hosts = builtins.listToAttrs (
      map (domain: {
        name = domain;
        value = "127.0.0.1";
      }) cfg.domains
    );

    languages.php = {
      enable = lib.mkDefault true;
      package = cfg.phpEnv;

      fpm.settings.error_log = "/dev/stderr";
      fpm.pools.web = {
        settings = {
          "clear_env" = "no";
          "pm" = "dynamic";
          "pm.max_children" = 10;
          "pm.start_servers" = 10;
          "pm.min_spare_servers" = 1;
          "pm.max_spare_servers" = 10;
          "request_terminate_timeout" = 360;
          "access.log" = "/dev/stderr";
          "php_value[memory_limit]" = "512M";
        };
      };
    };
  };
}
