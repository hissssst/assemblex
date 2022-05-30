let pkgs = import <nixpkgs> {};
in pkgs.mkShell rec {
  buildInputs = with pkgs; [ nasm gcc ];
  shellHook = ''
    export NIX_ENFORCE_PURITY=0
  '';
}


