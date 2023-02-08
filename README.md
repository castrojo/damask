<img style="vertical-align: middle;" src="data/icons/hicolor/scalable/apps/app.drey.Damask.svg" width="120" height="120" align="left">

# Damask

Damask is an application that will automatically set wallpaper images by
selecting images from a variety of sources, including local files and folders.
It currently supports setting the wallpaper image from the following sources:

* wallhaven.cc
* Microsoft Bing Wallpaper of the day
* NASA Astronomy Picture of the Day
* Unsplash

![application screenshot](./data/damask.png)

## Installation

<a href='https://flathub.org/apps/details/app.drey.Damask'><img width='180' height='60' alt='Download on Flathub' src='https://flathub.org/assets/badges/flathub-badge-en.svg'/></a>

```sh
flatpak install app.drey.Damask
```

## Translations

Damask is accepting translations through Weblate. If you'd like to contribute a
translation in your language, visit the [Weblate
project](https://hosted.weblate.org/engage/damask/).

<a href="https://hosted.weblate.org/engage/damask/">
  <img src="https://hosted.weblate.org/widgets/damask/-/damask/multi-auto.svg" alt="Translation status" />
</a>

## Development

Damask can be compiled and run with [GNOME
Builder](https://wiki.gnome.org/Apps/Builder) or locally using `meson` and `ninja`.

```sh
cd damask
mkdir _build
cd _build
meson configure ..
meson build
```
