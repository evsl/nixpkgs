{ lib, stdenv, fetchurl
, buildPackages, pkgsHostHost
, pkg-config, which, makeWrapper
, zlib, bzip2, brotli, libpng, gnumake, glib

, # FreeType supports LCD filtering (colloquially referred to as sub-pixel rendering).
  # LCD filtering is also known as ClearType and covered by several Microsoft patents.
  # This option allows it to be disabled. See http://www.freetype.org/patents.html.
  useEncumberedCode ? true

# for passthru.tests
, cairo
, fontforge
, ghostscript
, graphicsmagick
, gtk3
, harfbuzz
, imagemagick
, pango
, poppler
, python3
, qt5
, texmacs
, ttfautohint
, testers
}:


stdenv.mkDerivation (finalAttrs: {
  pname = "freetype";
  version = "2.13.0";

  src = let inherit (finalAttrs) pname version; in fetchurl {
    url = "mirror://savannah/${pname}/${pname}-${version}.tar.xz";
    sha256 = "sha256-XuI6vQR2NsJLLUPGYl3K/GZmHRrKZN7J4NBd8pWSYkw=";
  };

  propagatedBuildInputs = [ zlib bzip2 brotli libpng ]; # needed when linking against freetype

  # dependence on harfbuzz is looser than the reverse dependence
  nativeBuildInputs = [ pkg-config which ]
    ++ lib.optional (!stdenv.hostPlatform.isWindows) makeWrapper
    # FreeType requires GNU Make, which is not part of stdenv on FreeBSD.
    ++ lib.optional (!stdenv.isLinux) gnumake;

  patches = [
    ./enable-table-validation.patch
  ] ++ lib.optional useEncumberedCode ./enable-subpixel-rendering.patch;

  outputs = [ "out" "dev" ];

  configureFlags = [ "--bindir=$(dev)/bin" "--enable-freetype-config" ];

  # native compiler to generate building tool
  CC_BUILD = "${buildPackages.stdenv.cc}/bin/cc";

  # The asm for armel is written with the 'asm' keyword.
  CFLAGS = lib.optionalString stdenv.isAarch32 "-std=gnu99";

  enableParallelBuilding = true;

  doCheck = true;

  postInstall = glib.flattenInclude
    # pkgsCross.mingwW64.pkg-config doesn't build
    # makeWrapper doesn't cross-compile to windows #120726
    + lib.optionalString (!stdenv.hostPlatform.isMinGW) ''
    substituteInPlace $dev/bin/freetype-config \
      --replace ${buildPackages.pkg-config} ${pkgsHostHost.pkg-config}

    wrapProgram "$dev/bin/freetype-config" \
      --set PKG_CONFIG_PATH "$PKG_CONFIG_PATH:$dev/lib/pkgconfig"
  '';

  passthru.tests = {
    inherit
      cairo
      fontforge
      ghostscript
      graphicsmagick
      gtk3
      harfbuzz
      imagemagick
      pango
      poppler
      texmacs
      ttfautohint;
    inherit (python3.pkgs) freetype-py;
    inherit (qt5) qtbase;
    pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;
  };

  meta = with lib; {
    description = "A font rendering engine";
    longDescription = ''
      FreeType is a portable and efficient library for rendering fonts. It
      supports TrueType, Type 1, CFF fonts, and WOFF, PCF, FNT, BDF and PFR
      fonts. It has a bytecode interpreter and has an automatic hinter called
      autofit which can be used instead of hinting instructions included in
      fonts.
    '';
    homepage = "https://www.freetype.org/";
    license = licenses.gpl2Plus; # or the FreeType License (BSD + advertising clause)
    platforms = platforms.all;
    pkgConfigModules = [ "freetype2" ];
    maintainers = with maintainers; [ ttuegel ];
  };
})
