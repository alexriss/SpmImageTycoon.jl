<p align="center">
  <img width="100" height="100" src="res/media/logo_diamond_animated.svg?raw=true" />
</p>

# SpmImage Tycoon

Cross-platform app to manage and edit scanning probe microscopy (SPM) images and spectra. *Under development.*

Currently, [Nanonis](https://www.specs-group.com/nanonis/) scanning tunneling microscopy (STM) and atomic force microscopy (AFM) images and spectra are supported.

[Features](#features)  
[Demo](#demo)  
[Disclaimer](#disclaimer)  
[Installation](#installation)  
[Technical comments](#technical-comments)  
[Dependencies](#dependencies)  
[Third party libraries](#third-party-libraries-included)  
[Related projects](#related-projects)  


## Features

- Load and display Nanonis SPM images: grid and zoom views
- Load and display Nanonis spectra
- Fast keyboard-based navigation
- Cycle through channels, switch between forward and backward directions
- Different types of background corrections
- Various color palettes
- Star-rating and keyword systems
- Powerful search
- Line profiles *(experimental and not yet fully tested)*
- Overview and position-based filtering
- Export to [OpenDocument presentation](https://en.wikipedia.org/wiki/OpenDocument)
  (compatible with [LibreOffice](https://www.libreoffice.org/), [OpenOffice](https://www.openoffice.org/), [PowerPoint](https://en.wikipedia.org/wiki/Microsoft_PowerPoint), etc.)
- Everything is experimental. And we all like experiments.
  
## Demo

<table>
  <tr>
    <td>
      <a href="http://www.youtube.com/watch?v=x_KSCst92Lo" target="_blank"><img src="http://img.youtube.com/vi/x_KSCst92Lo/0.jpg" width="250" /></a>
    </td>
    <td>
      <a href="http://www.youtube.com/watch?v=FRl0HwMmiD4" target="_blank"><img src="http://img.youtube.com/vi/FRl0HwMmiD4/0.jpg" width="250" /></a>
    </td>
  </tr>
  <tr>
    <td>Feature demo (YouTube)</td>
    <td>Global scan frame filter (YouTube)</td>
  </tr>
</table>

## Disclaimer

_The app should be considered experimental. It has undergone limited testing, and while it works for me, I can not guarantee that it will work flawlessly for you aswell. It is conceivable that some of the calculations potentially give erroneous results under certain circumstances. So please only use the app if you are ok with some surprises._

_The app never modifies or deletes your original data. However, in case of any unexpected problems, you might lose the modifications saved within the app. Even though this has never happened to me, I still advice to backup the database regularly (I personally do not do that, though). The app creates a database in each project directory under `_spmimages_cache/db.jld2`. This file contains all your edits, keywords, etc. and can be copied as a backup. At some point I will include a backup functionality into the app, but this day is not today._

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

### You can stop reading here and start using the program now.


## Technical comments

The app is written in [Julia](https://julialang.org/), using [Blink.jl](https://github.com/JuliaGizmos/Blink.jl) for the [Electron](https://www.electronjs.org/)-based frontend.

- To gain a significant speedup through mutlithreading, start Julia with multiple threads, e.g.: `julia --threads 4`
- There is a small overhead to apply color schemes; for performance it is best to use the standard "gray" color scheme.

## Dependencies

The program relies on

- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.


#### Third party libraries (included)

The following javascript and css libraries are included in the app:

- [tagify](https://github.com/yairEO/tagify): MIT License
- [Simple-DataTables](https://github.com/fiduswriter/Simple-DataTables): LGPL License
- [Bulma](https://bulma.io/): MIT License
- [μPlot](https://github.com/leeoniya/uPlot): MIT License
- [SelectionJS](https://github.com/Simonwep/selection): MIT License

## Related projects

- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.
- [imag*ex*](https://github.com/alexriss/imagex): Python scripts to analyze scanning probe images.
- [grid*ex*](https://github.com/alexriss/gridex): Python scripts to analyze 3D grid data.
