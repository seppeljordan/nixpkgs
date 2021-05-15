{ rustPlatform
, runCommand
, lib
, fetchFromGitHub
, fetchgit
, makeWrapper
, pkg-config
, python2
, expat
, openssl
, SDL2
, vulkan-loader
, fontconfig
, ninja
, gn
, llvmPackages
, makeFontsConf
}:
rustPlatform.buildRustPackage rec {
  pname = "neovide";
  version = "20210515";

  src =
    let
      repo = fetchFromGitHub {
        owner = "Kethku";
        repo = "neovide";
        rev = "0b976c3d28bbd24e6c83a2efc077aa96dde1e9eb";
        sha256 = "sha256-asaOxcAenKdy/yJvch3HFfgnrBnQagL02UpWYnz7sa8=";
      };
    in
    runCommand "source" { } ''
      cp -R ${repo} $out
      chmod -R +w $out
      # Reasons for patching Cargo.toml:
      # - I got neovide built with latest compatible skia-save version 0.35.1
      #   and I did not try to get it with 0.32.1 working. Changing the skia
      #   version is time consuming, because of manual dependecy tracking and
      #   long compilation runs.
      sed -i $out/Cargo.toml \
        -e '/skia-safe/s;0.32.1;0.35.1;'
      cp ${./Cargo.lock} $out/Cargo.lock
    '';

  cargoSha256 = "sha256-XMPRM3BAfCleS0LXQv03A3lQhlUhAP8/9PdVbAUnfG0=";

  SKIA_OFFLINE_SOURCE_DIR =
    let
      repo = fetchFromGitHub {
        owner = "rust-skia";
        repo = "skia";
        # see rust-skia/Cargo.toml#package.metadata skia
        rev = "m86-0.35.0";
        sha256 = "sha256-uTSgtiEkbE9e08zYOkRZyiHkwOLr/FbBYkr2d+NZ8J0=";
      };
      # The externals for skia are taken from skia/DEPS
      externals = {
        expat = fetchgit {
          url = "https://chromium.googlesource.com/external/github.com/libexpat/libexpat.git";
          rev = "e976867fb57a0cd87e3b0fe05d59e0ed63c6febb";
          sha256 = "sha256-akSh/Vo7s7m/7qePamGA7oiHEHT3D6JhCFMc27CgDFI=";
        };
        libjpeg-turbo = fetchgit {
          url = "https://chromium.googlesource.com/chromium/deps/libjpeg_turbo.git";
          rev = "64fc43d52351ed52143208ce6a656c03db56462b";
          sha256 = "sha256-rk22wE83hxKbtZLhGwUIF4J816jHvWovgICdrKZi2Ig=";
        };
        icu = fetchgit {
          url = "https://chromium.googlesource.com/chromium/deps/icu.git";
          rev = "dbd3825b31041d782c5b504c59dcfb5ac7dda08c";
          sha256 = "sha256-voMH+TdNx3dBHeH5Oky5OYmmLGJ2u+WrMrmAkjXJRTE=";
        };
        zlib = fetchgit {
          url = "https://chromium.googlesource.com/chromium/src/third_party/zlib";
          rev = "eaf99a4e2009b0e5759e6070ad1760ac1dd75461";
          sha256 = "sha256-B4PgeSVBU/MSkPkXTu9jPIa37dNJPm2HpmiVf6XuOGE=";
        };
        harfbuzz = fetchgit {
          url = "https://chromium.googlesource.com/external/github.com/harfbuzz/harfbuzz.git";
          rev = "3a74ee528255cc027d84b204a87b5c25e47bff79";
          sha256 = "sha256-/4UdoUj0bxj6+EfNE8ofjtWOn2VkseEfvdFah5rwwBM=";
        };
        libpng = fetchgit {
          url = "https://skia.googlesource.com/third_party/libpng.git";
          rev = "386707c6d19b974ca2e3db7f5c61873813c6fe44";
          sha256 = "sha256-67kf5MBsnBBi0bOfX/RKL52xpaCWm/ampltAI+EeQ+c=";
        };
        libgifcodec = fetchgit {
          url = "https://skia.googlesource.com/libgifcodec";
          rev = "d06d2a6d42baf6c0c91cacc28df2542a911d05fe";
          sha256 = "sha256-ke1X5iyj2ah2NqGVdFv8GuoRAzXg1aCeTdZwUM8wvCI=";
        };
      };
    in
    runCommand "source" { } (''
      cp -R ${repo} $out
      chmod -R +w $out

      mkdir -p $out/third_party/externals
      cd $out/third_party/externals
    '' + (builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "cp -ra ${value} ${name}") externals)));

  SKIA_OFFLINE_NINJA_COMMAND = "${ninja}/bin/ninja";
  SKIA_OFFLINE_GN_COMMAND = "${gn}/bin/gn";
  LIBCLANG_PATH = "${llvmPackages.libclang}/lib";

  # test needs a valid fontconfig file
  FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ ]; };

  nativeBuildInputs = [
    pkg-config
    makeWrapper
    python2 # skia-bindings
    llvmPackages.clang # skia
  ];

  # All tests passes but at the end cargo prints for unknown reason:
  #   error: test failed, to rerun pass '--bin neovide'
  # Increasing the loglevel did not help. In a nix-shell environment
  # the failure do not occure.
  doCheck = false;

  buildInputs = [
    expat
    openssl
    SDL2
    fontconfig
  ];

  postFixup = ''
    wrapProgram $out/bin/neovide \
      --prefix LD_LIBRARY_PATH : ${vulkan-loader}/lib
  '';

  postInstall = ''
    for n in 16x16 32x32 48x48 256x256; do
      install -m444 -D "assets/neovide-$n.png" \
        "$out/share/icons/hicolor/$n/apps/neovide.png"
    done
    install -m444 -Dt $out/share/icons/hicolor/scalable/apps assets/neovide.svg
    install -m444 -Dt $out/share/applications assets/neovide.desktop
  '';

  meta = with lib; {
    description = "This is a simple graphical user interface for Neovim.";
    homepage = "https://github.com/Kethku/neovide";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ ck3d ];
    platforms = platforms.linux;
  };
}
