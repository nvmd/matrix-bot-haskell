{
  description = "";

  nixConfig = {
    bash-prompt = "\[nix-develop\|haskell\] ➜ ";
    extra-substituters = [
      "https://nixcache.reflex-frp.org"
    ];
    extra-trusted-public-keys = [
      "ryantrinkle.com-1:JJiAKaRv9mWgpVAz8dwewnZe0AzzEAzPkagE9SP5NWI="
    ];
    # timeout (in seconds) for establishing connections to the binary cache substituter
    connect-timeout = 5;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    matrix-client = {
      # url = "git+file:../matrix-client-haskell?shallow=1";
      url = "github:nvmd/matrix-client-haskell";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils
            , matrix-client
            , ... }@inputs: let
    defaultCompiler = "ghc96";
    nixTools = pkgs: with pkgs; [
      nil # lsp language server for nix
      nixpkgs-fmt
      nix-output-monitor
    ];
    hsTools = hsPkgs: with hsPkgs; [
      cabal-fmt
      cabal-install
      cabal2nix
      hoogle
      hspec-discover
      haskell-language-server
    ];

    hsPackage = pkgs: compilerVersion: isDevEnv: let
      forCompiler = pkgs.haskell.packages.${compilerVersion};
    in forCompiler.developPackage {
      root = ./.;
      source-overrides = {
        inherit matrix-client;
      };
      returnShellEnv = isDevEnv;
      modifier = drv: if isDevEnv
        then
          pkgs.haskell.lib.addBuildTools drv (
            (hsTools forCompiler) ++ (nixTools pkgs))
        else drv;
    };
  in flake-utils.lib.eachDefaultSystem (system: let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in {
      packages."matrix-bot-haskell" = hsPackage pkgs defaultCompiler false;
      packages.default = self.packages.${system}."matrix-bot-haskell";


      devShells.default = hsPackage pkgs defaultCompiler true;
      devShells.minimal = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          (haskellPackages.ghcWithPackages hsTools)
        ] ++ nixTools pkgs;
      };
    });
}
