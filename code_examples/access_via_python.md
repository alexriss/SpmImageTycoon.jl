## Accessing SpmImage Tycoon data via Python

This example shows how to access the Tycoon data via Python. We will read the database, pick a specific image and associated spectra and plot the image along with the locations of the spectra.

SpmImage Tycoon uses a [HDF5](https://en.wikipedia.org/wiki/Hierarchical_Data_Format)-compatible database, which can be read using the [h5py package](https://www.h5py.org/).

First, we import the necessary packages. The packages can be installed using `pip install <package name>`.

```python
import h5py
import matplotlib.pyplot as plt
import numpy as np
import os
import PIL.Image
```

Now, we define the function to read the database. The function takes the path to the data directory as an argument and returns a list of all the items in the database. You can just copy and paste the function into your code.

```python
def get_griditems(path):
    """Get the griditems from a HDF5 file. Returns a list of dictionaries."""

    # allow path to be a directory or a file
    if os.path.isdir(path):
        if "_spmimages_cache" not in path:
            path = os.path.join(path, "_spmimages_cache")
        db_file = os.path.join(path, "db.jld2")
    else:
        db_file = path

    with h5py.File(db_file, "r") as f:
        ref = f["griditems"][()]
        ref_griditems = f[ref][()]

        griditems = []
        ref = ref_griditems[0]
        ref = f[ref][()][1]
        fieldnames = f[ref][()].dtype.names
        for ref in ref_griditems:
            ref = f[ref][()][1]  # values
            griditem = f[ref][()]
            d = {}
            # ignore deleted items
            if griditem["status"] != 0:
                continue

            # cleanup data
            for k in fieldnames:
                v = griditem[k]
                # time field are stored as a np.void object
                while(isinstance(v, np.void) and len(v.dtype) == 1):
                    v = v[0]
                # convert bytes to string
                if isinstance(v, bytes):
                    v = v.decode("utf-8")
                # resolve references              
                elif isinstance(v, h5py.h5r.Reference):
                    v = f[v][()]
                    # nparray of bytes to string (for keyswords etc.)
                    if isinstance(v, np.ndarray) and v.dtype.char == "O":
                        v = v.astype(str)

                d[k] = v

            griditems.append(d)
    return griditems
```

Now, we use the function to load all the items from the database and find the item with the keyword `"Figure1"`. We load its associated image file (with all the edits done in the Tycoon GUI) and plot it.

```python
griditems = get_griditems(dir_data)
im = next(g for g in griditems if "Figure1" in g["keywords"])

fname = os.path.join(dir_data, "_spmimages_cache", im["filename_display"])
img = np.asarray(PIL.Image.open(fname))
imgplot = plt.imshow(img, extent=(0, im["scansize"][0],0, im["scansize"][1]))
```

Now let's find all the relevant spectra, i.e. the spectra that are in the region of the image and have a star-rating ≥ 3.

We have to take into account position, as well as the rotation of the image. These are stores which is stored in the `center` and `rotation` keys of the image item. But again, you can just copy and paste the `adjust_position` function into your code.

```python


```

OK, finally let's add a scale bar.

```python

```


Now let's save the whole thing as a svg file:

```python
plt.axis('off')  # remove the x and y axis
plt.savefig('Figure1.svg', bbox_inches='tight')
```
