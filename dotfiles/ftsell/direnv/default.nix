{
  enable = true;
  nix-direnv.enable = true;
  stdlib = builtins.readFile ./stdlib.sh;
}
