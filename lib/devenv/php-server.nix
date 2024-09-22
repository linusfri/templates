{ pkgs, lib, config, ... }:
let
  cfg = config.services.linusfri.phpServer;

  numberOfHosts = builtins.length cfg.domains;
  mainDomain = if numberOfHosts > 0 then builtins.elemAt cfg.domains 0 else "localhost";
  mainFullHttpsUrl = "https://${mainDomain}:${toString cfg.sslPort}";
  mainFullHttpUrl = "http://${mainDomain}:${toString cfg.port}";

  # The cert generated will be in the format CERTNAME+<NUMBER_OF_TESTDOMAINS - 1>. Therefore this logic has to be here
  certificateName = if numberOfHosts < 2 then mainDomain else "${mainDomain}+${builtins.toString (numberOfHosts - 1)}";
  serverName = lib.strings.concatMapStringsSep " " (domain: domain) cfg.domains;
in
{
  options.services.linusfri.phpServer = {
    enable = lib.mkEnableOption "Enable NGINX and PHP-FPM for web server.";
    
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
      default = mainDomain;
    };

    assetFallbackUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Asset fallback URL to redirect to for missing assets.";
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    env = {
      WP_HOME = "https://${mainDomain}:${toString cfg.sslPort}";
      WP_SITEURL = "https://${mainDomain}:${toString cfg.sslPort}/wp";
      SSL_CERT = "${config.env.DEVENV_STATE}/mkcert/${certificateName}.pem";
      SSL_CERT_KEY = "${config.env.DEVENV_STATE}/mkcert/${certificateName}-key.pem";
      SERVER_PORT = cfg.port;
      SERVER_SSL_PORT = cfg.sslPort;
    };

    packages = [ ];

    services.nginx = {
      enable = lib.mkDefault true;
      httpConfig = lib.mkDefault ''
        server {
          listen ${toString cfg.port};
          listen ${toString cfg.sslPort} ssl;
          ${if numberOfHosts > 0 then ''
            ssl_certificate     ${config.env.SSL_CERT};
            ssl_certificate_key ${config.env.SSL_CERT_KEY};
          '' else ""}
          # ssl_protocols       TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
          # ssl_ciphers         HIGH:!aNULL:!MD5;

          root ${config.env.DEVENV_ROOT}/${cfg.serveDir};
          index index.php index.html index.htm;
          server_name ${serverName};

          error_page 497 https://$server_name:$server_port$request_uri;

          location / {
            try_files $uri $uri/ /index.php$is_args$args;
          }

          location /phpmyadmin/ {
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Host $host;

            proxy_pass "http://127.0.0.1:9000/";
          }

          location ~ \.php$ {
            fastcgi_pass unix:${config.languages.php.fpm.pools.web.socket};
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param QUERY_STRING  $query_string;
            fastcgi_param REQUEST_METHOD  $request_method;
            fastcgi_param CONTENT_TYPE  $content_type;
            fastcgi_param CONTENT_LENGTH  $content_length;
            fastcgi_param SCRIPT_FILENAME  $request_filename;
            fastcgi_param SCRIPT_NAME  $fastcgi_script_name;
            fastcgi_param REQUEST_URI  $request_uri;
            fastcgi_param DOCUMENT_URI  $document_uri;
            fastcgi_param DOCUMENT_ROOT  $document_root;
            fastcgi_param SERVER_PROTOCOL  $server_protocol;
            fastcgi_param GATEWAY_INTERFACE CGI/1.1;
            fastcgi_param SERVER_SOFTWARE  nginx/$nginx_version;
            fastcgi_param REMOTE_ADDR  $remote_addr;
            fastcgi_param REMOTE_PORT  $remote_port;
            fastcgi_param SERVER_ADDR  $server_addr;
            fastcgi_param SERVER_PORT  $server_port;
            fastcgi_param SERVER_NAME  $server_name;
            fastcgi_param HTTPS   $https if_not_empty;
            fastcgi_param REDIRECT_STATUS  200;
            fastcgi_param HTTP_PROXY  "";
            fastcgi_buffer_size 512k;
            fastcgi_buffers 16 512k;
            fastcgi_param HTTP_HOST $host:${toString cfg.sslPort};

            # THIS CAUSES PROBLEMS IN WORDPRESS, PAGINATION
            # set $fastcgi_host $host:$remote_port;
            # if ($http_x_forwarded_host != \'\') {
            #     set $fastcgi_host $http_x_forwarded_host;
            # }
            # fastcgi_param HTTP_HOST $fastcgi_host;
          }

          ${if cfg.assetFallbackUrl != null then ''
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
          '' else ""}
        }
      '';
    };

    processes = {
      php_error.exec = "touch ${config.env.DEVENV_STATE}/php_error; tail -f ${config.env.DEVENV_STATE}/php_error";
      app_urls.exec = "echo SSL URL: ${mainFullHttpsUrl}; echo NON SSL URL: ${mainFullHttpUrl};";
    };

    scripts.browse.exec = "open 'https://${mainDomain}:${toString cfg.sslPort}'";

    certificates = cfg.domains;
    hosts = builtins.listToAttrs (map (domain: { name = domain; value = "127.0.0.1"; }) cfg.domains);

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
