{
  description = "Shared libraries for the Vox programming language";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # The compiler that builds these libraries. Its flake wraps the vox
    # binary with its own VOX_CORE_PATH, so `vox` works out of the box here.
    vox.url = "github:Vox-lang/vox";
  };

  outputs = { self, nixpkgs, flake-utils, vox }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        voxc = vox.packages.${system}.default;
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "vox-libs";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ voxc pkgs.nasm pkgs.binutils ];

          # The Makefile drives everything; LIBDIR is overridden because the
          # nix store has no lib64 convention.
          buildPhase = ''
            make VOX=vox
          '';
          checkPhase = ''
            make test VOX=vox
          '';
          doCheck = true;
          installPhase = ''
            make install VOX=vox PREFIX=$out LIBDIR=$out/lib INCDIR=$out/include/vox
          '';

          meta = with pkgs.lib; {
            description = "Shared libraries for the Vox programming language";
            homepage = "https://github.com/Vox-lang/vox-libs";
            license = licenses.gpl3Plus;
            platforms = platforms.linux;
          };
        };

        devShells.default = pkgs.mkShell {
          packages = [ voxc pkgs.nasm pkgs.binutils pkgs.gnumake ];
        };
      });
}
