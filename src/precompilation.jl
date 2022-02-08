function __init__()::Nothing
    load_spectrum("test/Z-Spectroscopy002.dat");  # a bit dirty, but this will properly trigger precompilation
    return nothing
end
