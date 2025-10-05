{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.linusfri.phpServer;
  mainDomain = if numberOfHosts > 0 then builtins.elemAt cfg.domains 0 else "localhost";
  numberOfHosts = builtins.length cfg.domains;
  mainFullHttpsUrl = "https://${mainDomain}:${toString cfg.sslPort}";
  mainFullHttpUrl = "http://${mainDomain}:${toString cfg.port}";

  common = {
    certificateName =
      if numberOfHosts < 2 then mainDomain else "${mainDomain}+${builtins.toString (numberOfHosts - 1)}";
    serverName = lib.strings.concatMapStringsSep " " (domain: domain) cfg.domains;

    inherit mainDomain;
    inherit mainFullHttpsUrl;
    inherit mainFullHttpUrl;
    inherit numberOfHosts;
  };

  nginxConfig = {
    wordpress = ''
      location / {
        try_files $uri $uri/ /index.php$is_args$args;
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
        fastcgi_param HTTP_HOST $host:${if cfg.https then toString cfg.sslPort else toString cfg.port};
      }
    '';

    laravel = '''';
  };

  envConfig = rec {
    common = {
      SSL_CERT = "${config.env.DEVENV_STATE}/mkcert/${cfg.commonServerConfig.certificateName}.pem";
      SSL_CERT_KEY = "${config.env.DEVENV_STATE}/mkcert/${cfg.commonServerConfig.certificateName}-key.pem";
      SERVER_PORT = cfg.port;
      SERVER_SSL_PORT = cfg.sslPort;
      MAIN_HTTPS_URL = cfg.commonServerConfig.mainFullHttpsUrl;
      MAIN_HTTP_URL = cfg.commonServerConfig.mainFullHttpUrl;
    };
  
    wordpress = rec {
      WP_ENV = "development";
      WP_HOME = if cfg.https then mainFullHttpsUrl else mainFullHttpUrl;
      WP_SITEURL = "${WP_HOME}/wp";
      ENABLE_BROWSERSYNC_SSL = "true";
      MAIN_DOMAIN = cfg.mainDomain;

      AUTH_KEY = ".=NxGVvv{Sm9ixp^{Q6;!u@TU<Zy56fVRf@Sx1ZMAG:7)9)cOwM3d-*WR!:L=|l0";
      SECURE_AUTH_KEY = ".@,|??19?V0,5]l)J*S>IW?w-c!+.|b;#oif&C_^W[-I1:m}8Ry$(,B-m|Rv*>!+";
      LOGGED_IN_KEY = "&xoyJj|;YsY!NDl#Sr6WkK%H7B_f]raj=L>BUHxGVN&xDbhS.2p=u635LQ,eXOdj";
      NONCE_KEY = "Dn7V6gzN_MTj*rr>]LNB[72zI:}Gj4C3(3{sJ)S9CM$p-bo:GP.D9kH*r-Q$Q95D";
      AUTH_SALT = "g^W]C9]F>CV0=5L9Al%_&$:px@sy*B&qk88#:6NbJh$4r:6ngH8.fm^3;Rir%E<g";
      SECURE_AUTH_SALT = "2ul=MG0quBB[aS<>xr)WxBKJ`2@83+h;Bq^AH^Oo!?YyEVeZ8y3ax:Vh?[uH=0=?";
      LOGGED_IN_SALT = "1!ER/AN9GW^l6(I%{owxJ>/G10FT^.iL,&POfDYH^b2}OI1omyM;R/[C[}Bi`k8R";
      NONCE_SALT = "4as<0(,O=^Y1mN=aYU1YV6HE6A,;5&-my_GjXLeKCU2*zEPzi=eDM5s34&`J{_!D";

    } // common;

    laravel = { } // common;
  };
in
{
  options.services.linusfri.phpServer = {
    commonServerConfig = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      default = common;
    };

    nginxConfig = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      default = nginxConfig;
    };

    envConfig = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      default = envConfig;
    };
  };
}
