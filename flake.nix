{
  description = "Flake for project outputs.";
  outputs = { ... }: {
    templates.wp-flake = {
      path = ./templates/wp-project;
      description = "A wordpress template using Nix flake and Devenv.";
    };
  };
}
