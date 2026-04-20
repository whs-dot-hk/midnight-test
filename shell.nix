{
  pkgs ? import (import ./npins).nixpkgs {
    config.allowUnfree = true;
  }
}:

pkgs.mkShell {
  buildInputs = [
    pkgs.awscli2
    pkgs.terraform
  ];
}
