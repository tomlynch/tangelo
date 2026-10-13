# Third-party notices

Tangelo's own source code is licensed under the MIT License (see `LICENSE`).
Tangelo bundles the following third-party software, which keeps its own license.

## VLCKit / libVLC

- **Component:** VLCKit 3.7.3 for macOS (binary package `VLCKit-3.7.3-319ed2c0-79128878`), which
  contains libVLC, libvlccore, and the VLC playback plugins statically linked into `VLCKit.framework`.
- **License:** GNU Lesser General Public License, version 2.1 or later. The full text ships in the app as
  `VLCKit-COPYING.txt` and in this repository at `Vendor/VLCKit-COPYING.txt` after running
  `scripts/fetch-vlckit.sh`.
- **Copyright:** VideoLAN and the VLC authors.
- **Source code:** https://code.videolan.org/videolan/VLCKit (tag `3.7.3`) and
  https://code.videolan.org/videolan/vlc (3.0.x branch). Each Tangelo release also attaches the
  corresponding VLCKit source archive, as required by LGPL-2.1 section 6.
- **Relinking:** VLCKit is a separate, dynamically linked framework in `Tangelo.app/Contents/Frameworks/`.
  You may replace it with a modified build of the same version.

VLCKit's own build statically includes third-party libraries, each under a license compatible with
LGPL-2.1 distribution, including: FFmpeg (libavcodec, libavformat, libavutil, libswscale; built under
LGPL-2.1+), dav1d, libaom, libvpx, Opus, FLAC, Vorbis, Theora, Speex, mpg123, libass, FreeType,
HarfBuzz, FriBidi, TagLib, libxml2, live555, libnfs, libsmb2, libdsm, libssh2, libarchive, libsoxr,
libebur128, libspatialaudio, zvbi, and libupnp. Their license texts are in the VLCKit source tree under
`libvlc/vlc/contrib/src/`.

The bundled VLCKit build contains no GPL-only plugins (no libdvdcss, libdvdnav, liba52, faad2, or
libpostproc), which keeps the bundled engine's obligations to the LGPL alone.

## Trademarks

"VLC", "VideoLAN" and the VLC cone logo are trademarks of VideoLAN. Tangelo is not affiliated with or
endorsed by VideoLAN, and doesn't use their marks except to credit libVLC as its playback engine.
