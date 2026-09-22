{
  description = "Mount MTP devices as local filesystems via FUSE";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      rust-overlay,
      ...
    }:
    # Linux only: the mount path needs libfuse3, and macOS support relies on
    # macFUSE, which has no upstream nixpkgs package.
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-analyzer"
            "rust-src"
          ];
        };

        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };

        cargoTOML = fromTOML (builtins.readFile ./Cargo.toml);
        cargoLock = ./Cargo.lock;
      in
      {
        packages = rec {
          default = mtp-mount;

          mtp-mount = rustPlatform.buildRustPackage {
            pname = cargoTOML.package.name;
            version = cargoTOML.package.version;
            cargoLock.lockFile = cargoLock;
            src = ./.;

            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.fuse3 ];

            doCheck = false; # Skip tests for now
          };
        };

        devShells.default = pkgs.mkShell {
          packages = [
            rustToolchain
            pkgs.pkg-config
            pkgs.fuse3
            pkgs.cargo-audit
            pkgs.cargo-deny
            pkgs.just
          ];
        };
      }
    );
}
