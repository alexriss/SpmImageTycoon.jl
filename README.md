# SpmImage Tycoon

Cross-platform app to manage and edit scanning probe microscopy (SPM) images.

Currently, [Nanonis](https://www.specs-group.com/nanonis/) scanning tunneling microscopy (STM) and atomic force microscopy (AFM) images are supported. Under development.

## Features

- Load and display Nanonis SPM images: grid and zoom views
- Fast - keyboard-based navigation
- Cycle through channels, switch between forward and backward directions
- Different types of background corrections
- Various color palettes
- Star-rating and keyword systems
- Powerful search

## Technical comments

The app is written in [Julia](https://julialang.org/), using [Blink.jl](https://github.com/JuliaGizmos/Blink.jl) for the [Electron](https://www.electronjs.org/)-based frontend.

- To gain a significant speedup through mutlithreading, start Julia with multiple threads, e.g.: `julia --threads 4`
- There is some overhead to apply color schemes; for performance it is best to use the standard "gray" color scheme.

## Dependencies

The program relies on

- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.

which is currently not yet in the  default Julia package registry.


### Third party libraries

The following javascript libraries are included in the app:

- [tagify](https://github.com/yairEO/tagify): MIT License
- [Simple-DataTables](https://github.com/fiduswriter/Simple-DataTables): LGPL License

## Related projects

- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.
- [imag*ex*](https://github.com/alexriss/imagex): Python scripts to analyze scanning probe images.
- [grid*ex*](https://github.com/alexriss/gridex): Python scripts to analyze 3D grid data.
