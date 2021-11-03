{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.spin

    # keep this line if you use bash
    pkgs.bashInteractive
  ];
}
