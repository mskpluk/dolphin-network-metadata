# dolphin-network-metadata

Dolphin shows only the basics (type, size, dates) for files on mounted network
shares, both in tooltips and in the Information panel. This brings the full
details back:

* video: duration, resolution, codecs, bitrate, frame rate
* audio: artist, album, title, bitrate
* images: dimensions, camera and other EXIF data
* documents: page count, author, word count
* folders: number of items (and hidden items)
* tags, rating and comments in the Information panel (stored as extended
  attributes on the share, if the server supports them)

It's a long-standing KDE issue: [bug 452924](https://bugs.kde.org/show_bug.cgi?id=452924).
Dolphin treats network filesystems (cifs and NFS; from KDE Frameworks 6.31
also sshfs, rclone and other remote mounts) as "slow" and skips reading
metadata from them, even on a fast home network.

## Install

You need a C compiler (`gcc` or `clang`) and Dolphin from KDE Frameworks 6.

```sh
git clone https://github.com/mskpluk/dolphin-network-metadata.git
cd dolphin-network-metadata
./install.sh
```

Then close all Dolphin windows and start it again.

Everything goes into your home directory, no root needed:

* `~/.local/lib/dolphin-network-metadata/dolphin-network-metadata.so`
* `~/.local/bin/dolphin`: a small wrapper that starts the real Dolphin with the
  library loaded
* `~/.config/systemd/user/plasma-dolphin.service.d/dolphin-network-metadata.conf`:
  the same for Dolphin started in the background by Plasma

`~/.local/bin` has to come before `/usr/bin` in your `PATH`. Most distributions
add it at login, but only if the directory already exists, so if the installer
had to create it, log out and back in once. The installer tells you if that's
needed, or if `PATH` is set up differently.

## Uninstall

```sh
./uninstall.sh
```

Then restart Dolphin.

## How it works

The library is loaded into Dolphin with `LD_PRELOAD` and changes one answer:
when the metadata widget asks whether a file is on a slow filesystem, it says
no. Everything else in Dolphin still gets the real answer, so things like the
size limit for remote previews keep working. It doesn't depend on how KDE
detects network filesystems, so it keeps working when that changes.

Programs you open from Dolphin don't inherit the library.

## Limitations

* Reading metadata means reading part of the file over the network. On a slow
  link, tooltips for files on shares will take longer to appear.
* Only Dolphin is covered; other programs (file dialogs etc.) behave as before.
* If Dolphin is started some other way (e.g. by its full path), it runs without
  the library and simply behaves as before.

## License

GPL-3.0-or-later
