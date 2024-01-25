with import <nixpkgs> {};
let
  pythonPackages = ps:
    with ps; [
      argcomplete

      # Linting
      black
      mypy
      pylint
    ];
in mkShell rec {
  buildInputs = [
    python

    # Linting + development
    nodePackages.pyright
    bashInteractive

    # Python development
    (python310.withPackages pythonPackages)
  ];
}
