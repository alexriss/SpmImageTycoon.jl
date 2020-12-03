# SpmImage Tycoon

App to manage and edit SPM (scanning probe microscopy) images. Currently limited functionality. Under heavy development.

## Technical comments

To gain a significant speedup through mutlithreading, start Julia with multiple threads, e.g.: `julia --threads 4`

## Dependencies

The program relies on

- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.

which is currently not yet in the  default Julia package registry.

## Related projects

- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.
- [imag*ex*](https://github.com/alexriss/imagex): Python scripts to analyze scanning probe images.
- [grid*ex*](https://github.com/alexriss/gridex): Python scripts to analyze 3D grid data.