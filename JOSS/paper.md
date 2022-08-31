---
title: 'SpmImage Tycoon: Organize and analyze scanning probe microscopy data'
tags:
  - Julia
  - scanning probe microscopy
  - scanning probe spectroscopy
  - scanning tunneling microscopy
  - scanning tunneling spectroscopy
  - atomic force microscopy
  - SPM
  - STM
  - AFM
authors:
  - name: Alexander Riss
    orcid: 0000-0002-3212-7925
    corresponding: true # (This is how to denote the corresponding author)
    affiliation: 1
affiliations:
 - name: Technical University of Munich, Physics Department E20, 85748 Garching, Germany
   index: 1
date: 1 August 2022
bibliography: paper.bib
---

# Summary

`SpmImage Tycoon` is a cross-platform application designed for fast and effortless organization, analysis, and editing of scanning probe microscopy images and spectra. The application supports automatic channel-of-interest detection, image editing (such as background corrections and contrast adjustment), keywording, star-ratings, powerful search and filtering (e.g., by keywords, data type, location, scan size), as well as export of the data into an OpenDocument Presentation file format [@oasisodp]. Such easy-to-use tools can lower the entry barrier for aspiring scientists, boost the efficiency of experienced researchers, and help to create and leverage large scanning probe microscopy datasets for machine learning and artificial intelligence applications.

# Statement of need

The evolution of the field of scanning probe microscopy has been associated with development of instrumental capabilities and methods for data acquisition and analysis [@wsxm; @gwyddion; @imagej; @imagej2; @fiji; @spectrafox]. However, much less emphasis has been placed on improving the management and organization of the measured datasets. Mature and capable tools for processing and analysis of images and spectra exist, e.g., WSxM [@wsxm], Gwyddion [@gwyddion], ImageJ [@imagej], ImageJ2 [@imagej2], Fiji [@fiji], and SpectraFox [@spectrafox]. However, the workflow for browsing and manage data is less developed and thus users often resort to organization in filesystem folders and manually created lists of the best measurements. This can make common operations of tagging and editing selected subsets of images or spectra rather cumbersome. Furthermore, while datasets can consist of thousands of images and spectra per project, it is not uncommon for researchers to go through each image or spectrum and manually select the channels of interest for each one – only to repeat the same procedure every time they want to analyze their data again. `SpmImage Tycoon` aims to solve these problems by providing a fast and convenient way to browse, organize, analyze, and batch edit images and spectra obtained in scanning tunneling microscopy (STM) and atomic force microscopy (AFM) experiments.

# Implementation

`SpmImage Tycoon` is written in Julia [@Julia-2017] and uses JavaScript/Electron [@electronjs] for the frontend. It can be easily installed and updated via Julia's package manager [@juliapkg] and runs on all major desktop platforms.

The initial parsing of a project folder generates and saves the respective visual representations of the data (i.e., images and graphs). The whole process usually takes less than one minute for a few thousand images and spectra. Subsequently, the project can be re-opened within a second or two. The generated images and spectra are saved to the filesystem and all the respective keywords, ratings, and edits are stored in an HDF5 [@hdf5] compatible file format and thus can easily be accessed outside of `SpmImage Tycoon`, from different programming languages.

Due to its modular design, new features can be added to `SpmImage Tycoon` in future development. Moreover it will be possible to extend its use to other experimental methods that generate one-dimensional or two-dimensional data (such as spectroscopic and microscopic techniques).

# Acknowledgements

A.R. acknowledges funding by the Deutsche Forschungsgemeinschaft (DFG, German Research Foundation) – 453903355.

# References
