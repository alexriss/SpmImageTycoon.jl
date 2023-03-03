<p align="center">
  <img width="100" height="100" src="res/media/logo_diamond_animated.svg?raw=true" />
</p>

# SpmImage Tycoon

Cross-platform app to manage and edit scanning probe microscopy (SPM) images and spectra.

Currently, [Nanonis](https://www.specs-group.com/nanonis/) scanning tunneling microscopy (STM) and atomic force microscopy (AFM) images and spectra are supported.

[Features](#features)  
[Demo](#demo)  
[Disclaimer](#disclaimer)  
[Installation](#installation)  
[Installation (alternative)](#alternative-installation)  
[Cite](#cite)  
[Case study](#real-world-case-study)  
[Tips and tricks](#tips-and-tricks)  
[Technical background](#technical-background)  
[Third party libraries](#third-party-libraries-included)  
[Contribute](#get-in-touch-and-contribute)  
[Related projects](#related-projects)  


## Features

- Load and display Nanonis SPM images: grid and zoom views
- Load and display Nanonis spectra
- Fast keyboard-based navigation
- Cycle through channels, switch between forward and backward directions
- Different types of background corrections
- Various color palettes
- Non-destructive edits: Gaussian, Laplacian, Fourier Filter, etc.
- Line profiles
- Star-rating and keyword systems
- Powerful search and filtering (e.g., by keywords, data type, location, scan size)
- Overview and position-based filtering
- Export to [OpenDocument presentation](https://en.wikipedia.org/wiki/OpenDocument)
  (compatible with [LibreOffice](https://www.libreoffice.org/), [OpenOffice](https://www.openoffice.org/), [PowerPoint](https://en.wikipedia.org/wiki/Microsoft_PowerPoint), etc.)
- Everything is experimental. And we all like experiments.
  
## Demo

<table>
  <tr>
    <td>
      <a href="http://www.youtube.com/watch?v=x_KSCst92Lo" target="_blank"><img src="http://img.youtube.com/vi/x_KSCst92Lo/0.jpg" width="230" /></a>
    </td>
    <td>
      <a href="http://www.youtube.com/watch?v=FRl0HwMmiD4" target="_blank"><img src="http://img.youtube.com/vi/FRl0HwMmiD4/0.jpg" width="230" /></a>
    </td>
    <td>
      <a href="https://www.youtube.com/watch?v=nIBMQAzwzQs" target="_blank"><img src="http://img.youtube.com/vi/nIBMQAzwzQs/0.jpg" width="230" /></a>
    </td>
  </tr>
  <tr>
    <td>Feature demo<br />(YouTube)</td>
    <td>Global scan frame filter<br />(YouTube)</td>
    <td>Copy and paste parameters<br />(YouTube)</td>
  </tr>
  <tr>
    <td>
      <a href="demo/screenshot_gridview.jpg?raw=true" target="_blank"><img src="demo/screenshot_gridview.jpg?raw=true" width="230" /></a>
    </td>
    <td>
      <a href="demo/screenshot_spectrum.jpg?raw=true" target="_blank"><img src="demo/screenshot_spectrum.jpg?raw=true" width="230" /></a>
    </td>
    <td>
      <a href="https://www.youtube.com/watch?v=fz8UmxgXNqk" target="_blank"><img src="http://img.youtube.com/vi/fz8UmxgXNqk/0.jpg" width="230" /></a>
    </td>
  </tr>
  <tr>
    <td>Grid view: images and spectra<br />(Screenshot)</td>
    <td>Spectrum display<br />(Screenshot)</td>
    <td>Spectra demo <br />(YouTube)</td>
  </tr>
  <tr>
    <td>
      <a href="https://www.youtube.com/watch?v=rnk2hWuwpuI" target="_blank"><img src="http://img.youtube.com/vi/rnk2hWuwpuI/0.jpg" width="230" /></a>
    </td>
    <td>
      <a href="https://www.youtube.com/watch?v=VE_RGMeDTFc" target="_blank"><img src="http://img.youtube.com/vi/VE_RGMeDTFc/0.jpg" width="230" /></a>
    </td>
    <td align="center">
      <i>More features coming soon...</i>
      &nbsp;
      <br /><br />
    </td>
  </tr>
  <tr>
    <td>Non-destructive edits<br />(YouTube)</td>
    <td>Fourier filter<br />(YouTube)</td>
    <td></td>
  </tr>
</table>

It is best to play around with the app yourself, so [go ahead and install it.](#installation). Example data can be found in the [test directory](test/data).

## Disclaimer

_The app should be considered experimental. It has undergone limited testing, and while it works for me, I can not guarantee that it will work flawlessly for you aswell. It is conceivable that some of the calculations potentially give erroneous results under certain circumstances. So please only use the app if you are ok with some surprises._

_The app never modifies or deletes your original data. However, in case of any unexpected problems, you might lose the modifications saved within the app. Even though this has never happened to me, I still advice to backup the database regularly (I personally do not do that, though). The app creates a database in each project directory under `_spmimages_cache/db.jld2` (some older versions of this file are kept as well). This file contains all your edits, keywords, etc. and can be copied as a backup. Any filesystem backup solution should handle this._

## Installation

_Please only use the app if you read the disclaimer above and feel brave enough to do so._

To install and use, do the following:

1. Install [Julia](https://julialang.org/)
2. Start Julia and type the following two commands:
```julia
using Pkg
Pkg.add("SpmImageTycoon")
```
3. To run the app, type (within Julia):
```julia
using SpmImageTycoon
tycoon()
```
(if there are any firewall requests, please accept them - it is only for local server/client communication)

4. As a more convenient alternative to 3, just use one of the scripts in the [helpers directory](helpers/) to start the app. There is a [shell script](helpers/SpmImageTycoon.sh) for linux, as well as a [bat script](helpers/windows_tray/SpmImageTycoon.bat) for windows and also an [autohotkey script](helpers/windows_tray/SpmImageTycoon.ahk). You can find more information on autohotkey [here](https://www.autohotkey.com/).

### Update an existing installation

1. Start Julia and type the following two commands:
```julia
using Pkg
Pkg.update()
```
2. done


## Alternative Installation

As an alternative to the installation process described above, you can use [SpmImage Tycoon Installer](https://github.com/alexriss/SpmImageTycoonInstaller.jl). It will install a compiled version of SpmImage Tycoon with much improved startup speed. Furthermore, it can create startmenu and desktop shortcuts. This way of installation also allows to copy the app from one computer to another, by simply copying the installation directory.

This will become the main way of installation in the future.

## Cite

If you use the app for your scientific work, please consider citing it:

[![DOI](https://joss.theoj.org/papers/10.21105/joss.04644/status.svg)](https://doi.org/10.21105/joss.04644)

```bibtex
@article{Riss_JOSS_2022,
  doi = {10.21105/joss.04644},
  url = {https://doi.org/10.21105/joss.04644},
  year = {2022},
  publisher = {The Open Journal},
  volume = {7},
  number = {77},
  pages = {4644},
  author = {Alexander Riss},
  title = {SpmImage Tycoon: Organize and analyze scanning probe microscopy data},
  journal = {Journal of Open Source Software}
}
```

> ### _You can stop reading here and start using the app now._

## Real world case study

![image](demo/cartoon.jpg?raw=true)

## Tips and tricks

- Fast access to the file system is crucial - do not use this app on a slow networked file system.
- The first startup after installation (or update) can be slow - it is due to initial compilations. I am working on a solution to this.
- To gain a significant speedup through mutlithreading, start Julia with multiple threads, e.g.: `julia --threads=auto`
- There is a small overhead to apply color schemes; for performance it is best to use the standard "gray" color scheme.
- Extra settings (such as default channels and the default color scheme) can be changed in the `<homedir>/.spmimagetycoon/settings.toml` file.

> ### _Ok, now you really can stop reading._

## Technical background

The app is written in [Julia](https://julialang.org/), using [Blink.jl](https://github.com/JuliaGizmos/Blink.jl) for the [Electron](https://www.electronjs.org/)-based frontend.

The Julia source code is in the [src directory](/src/), the HTML, CSS, and JavaScript source code for the frontend is in the [res directory](/res/).

### Dependencies

The program relies on

- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.
- [SpmSpectroscopy.jl](https://github.com/alexriss/SpmSpectroscopy.jl): Julia library to read and analyze SPM spectra.


#### Third party libraries (included)

The following javascript and css libraries are included in the app:

- [Bulma](https://bulma.io/): MIT License
- [μPlot](https://github.com/leeoniya/uPlot): MIT License
- [SelectionJS](https://github.com/Simonwep/selection): MIT License
- [Simple-DataTables](https://github.com/fiduswriter/Simple-DataTables): LGPL License
- [Sortable](https://github.com/SortableJS/Sortable): MIT License
- [tagify](https://github.com/yairEO/tagify): MIT License

### Automated tests

[![Build Status](https://github.com/alexriss/SpmImageTycoon.jl/workflows/CI/badge.svg)](https://github.com/alexriss/SpmImageTycoon.jl/actions)
[![Coverage](https://codecov.io/gh/alexriss/SpmImageTycoon.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/alexriss/SpmImageTycoon.jl)
[![SpmImageTycoon Downloads](https://shields.io/endpoint?url=https://pkgs.genieframework.com/api/v1/badge/SpmImageTycoon)](https://pkgs.genieframework.com/?packages=SpmImageTycoon)

## Get in touch and contribute

Contributions are very welcome. Please post issues, suggestions, and pull requests on github. If you want to contribute to the code, take a look at the [technical background](#technical-background) and [contribution guidelines](CONTRIBUTING.md); and please get in touch with me.

<a href="https://twitter.com/00alexx">Follow me on twitter</a> for updates and more information about this project: 
<a href="https://twitter.com/00alexx"><img src="https://img.shields.io/twitter/follow/00alexx?style=social" alt="Twitter"></a>

## Related projects

- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.
- [SpmSpectroscopy.jl](https://github.com/alexriss/SpmSpectroscopy.jl): Julia library to read and analyze SPM spectra.
- [SpmGrids.jl](https://github.com/alexriss/SpmGrids.jl): Julia library to read and analyze SPM grid spectroscopy.
- [imag*ex*](https://github.com/alexriss/imagex): Python scripts to analyze scanning probe images.
- [grid*ex*](https://github.com/alexriss/gridex): Python scripts to analyze 3D grid data.
