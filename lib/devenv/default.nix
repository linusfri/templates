{ ... }:
{
  imports = [
    ./rust-server.nix
    ./mysql-db.nix
    ./phpmyadmin.nix
    ./php-server.nix
    ./sphinx-search.nix
  ];
}
