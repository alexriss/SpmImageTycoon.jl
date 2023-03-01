# a edit key "n" will be added automatically from js (this is used as an id)
# pars of type `info` will not be displayed - they are used for communication between js and julia

editing_entries = OrderedDict(
    "image" => OrderedDict(
        "G" => Dict(
            "name" => "Gaussian",
            "type" => "table",
            "pars" => OrderedDict(
                "s" => Dict(
                    "type" => "float",
                    "name" => "&sigma;",
                    "default" => 0.05,
                    "step" => 0.01,
                    "min" => 0.0,
                    "digits" => 3,
                    "unit" => "nm",
                )
            ),
            "abbreviation" => "G",
            "function" => "Gaussian",
        ),
        "L" => Dict(
            "name" => "Laplacian",
            "type" => "table",
            "pars" => OrderedDict(),
            "abbreviation" => "L",
            "function" => "Laplacian",
        ),
        "DoG" => Dict(
            "name" => "Difference of Gaussians",
            "type" => "table",
            "pars" => OrderedDict(
                "s1" => Dict(
                    "type" => "float",
                    "name" => "&sigma;<sub>1</sub>",
                    "default" => 0.025,
                    "step" => 0.01,
                    "min" => 1e-8,
                    "digits" => 3,
                    "unit" => "nm",
                ),
                "s2" => Dict(
                    "type" => "float",
                    "name" => "&sigma;<sub>2</sub>",
                    "default" => 0.05,
                    "step" => 0.01,
                    "min" => 1e-8,
                    "digits" => 3,
                    "unit" => "nm",
                )
            ),
            "function" => "DoG",
            "abbreviation" => "DoG",
        ),
        "LoG" => Dict(
            "name" => "Laplacian of Gaussian",
            "type" => "table",
            "pars" => OrderedDict(
                "s" => Dict(
                    "type" => "float",
                    "name" => "&sigma;",
                    "default" => 0.05,
                    "step" => 0.01,
                    "min" => 1e-8,
                    "digits" => 3,
                    "unit" => "nm",
                )
            ),
            "abbreviation" => "LoG",
            "function" => "LoG",
        ),
        "FTF" => Dict(
            "name" => "Fourier Filter",
            "type" => "table",
            "more" => [4, 7],
            "pars" => OrderedDict(
                "ps" => Dict(
                    "type" => "info",
                    "name" => "Pixel size",
                    "default" => [0, 0],
                ),
                "mf" => Dict(
                    "type" => "info",
                    "name" => "Maximum frequency",
                    "default" => [0, 0],
                ),
                "f" => Dict(
                    "type" => "select",
                    "name" => "Filter",
                    "options" => OrderedDict(
                        "p" => "keep",
                        "r" => "remove",
                    ),
                    "default" => "r",
                ),
                "w" => Dict(
                    "type" => "select",
                    "name" => "Window",
                    "options" => OrderedDict(
                        "" => "none",
                        "hn" => "hanning",
                        "hm" => "hamming",
                        "tk" => "tukey",
                        "cs" => "cosine",
                        "lc" => "lanczos",
                        "tr" => "triangular",
                        "ba" => "bartlett",
                        "ga" => "gaussian",
                        "bh" => "bartlett-hann",
                        "bl" => "blackman",
                        "ka" => "kaiser",
                    ),
                    "default" => "",
                ),
                "wf" => Dict(
                    "type" => "float",
                    "name" => "Window factor",
                    "default" => 1.00,
                    "step" => 0.1,
                    "min" => 0.0,
                    "max" => 1000000,
                    "digits" => 2,
                    "unit" => "",
                ),
                "s" => Dict(
                    "type" => "select",
                    "name" => "Normalization",
                    "options" => OrderedDict(
                        "li" => "linear",
                        "sq" => "square root",
                        "ln" => "logarithmic",
                    ),
                    "default" => "ln",
                ),
                "d" => Dict(
                    "type" => "select",
                    "name" => "Display",
                    "options" => OrderedDict(
                        "a" => "absolute",
                        "r" => "real",
                        "i" => "imaginary",
                    ),
                    "default" => "a",
                ),
                "r" => Dict(
                    "type" => "FT_select",
                    "name" => "selection",
                    "default" => [],
                )
            ),
            "abbreviation" => "FFT",
            "function" => "FTF",
        ),
    ),

    "spectrum" => OrderedDict(
        "G" => Dict(
            "name" => "Gaussian",
            "type" => "table",
            "pars" => OrderedDict(
                "s" => Dict(
                    "type" => "float",
                    "name" => "&sigma;",
                    "default" => 2,
                    "step" => 1,
                    "dragstep" => 0.1,
                    "min" => 0.0,
                    "digits" => 1,
                    "unit" => "points",
                )
            ),
            "abbreviation" => "G",
            "function" => "Gaussian",
        ),
        "dy" => Dict(
            "name" => "Difference",
            "type" => "table",
            "pars" => OrderedDict(),
            "abbreviation" => "dy",
            "function" => "diff1",
        ),
    )
)


MatrixFloat = Union{Matrix{Float32}, Matrix{Float64}}
VectorFloat = Union{Vector{Float32}, Vector{Float64}}


"""Returns a string with the active edits for the given griditem."""
function get_active_edits_str(griditem::SpmGridItem)::String
    if griditem.type == SpmGridImage
        editing_entries_ = editing_entries["image"]
    elseif griditem.type == SpmGridSpectrum
        editing_entries_ = editing_entries["spectrum"]
    else
        return ""
    end

    edits = map(griditem.edits) do edit_str
        edit = JSON.parse(edit_str, dicttype=OrderedDict)
        haskey(edit, "off") && edit["off"] > 0 && return ""
        if !haskey(editing_entries_, edit["id"])
            @warn "Unknown edit id: $(edit["id"])"
            return ""
        end
        return editing_entries_[edit["id"]]["abbreviation"]
    end
    edits = filter(x-> x!= "", edits)
    return join(edits, ", ")
end


"""Converts nm to pixels."""
function nm_to_px(griditem::SpmGridItem, points::Tuple{Int,Int}, val::Real)::Tuple{Float64,Float64}
    return Tuple(val .* points ./ griditem.scansize)
end


"""Generates the filename that is used for edits."""
function get_filename_edit(filename_display::String, suffix::String="")::String
    base, ext = splitext(filename_display)
    return "$(base)_$(suffix)$(ext)"
end


"""returns the edits directory (which is a subdirectory of dir_cache"""
function get_dir_edits(dir_cache::String)::String
    return joinpath(dir_cache, dir_edits_name)
end


"""converts and checks parameters corresponding to the given edit."""
function get_params(pars::AbstractDict, default_pars::OrderedDict)::OrderedDict
    res = OrderedDict()
    for (k,v) in pars
        if haskey(default_pars, k)
            if default_pars[k]["type"] == "float"
                if !isa(v, Real)
                    try
                        v = parse(Float64, v)
                    catch
                        v = default_pars[k]["default"]
                    end
                end
                if haskey(default_pars[k], "min") && v < default_pars[k]["min"]
                    v = default_pars[k]["min"]
                end
                if haskey(default_pars[k], "max") && v > default_pars[k]["max"]
                    v = default_pars[k]["max"]
                end
            end
            res[k] = v
        end
    end
    return res
end


"""Applies all edits to the images and spectra.
`args` is either `MatrixFloat` (for images) or `VectroFloat`, `VectorFloat` (for spectra).
"""
function apply_edits!(griditem::SpmGridItem, args...; dir_cache::String="")::Nothing
    for (i,edit) in enumerate(griditem.edits)
        edit = JSON.parse(edit, dicttype=OrderedDict)
        if "id" in keys(edit)
            id = edit["id"]
            if "off" in keys(edit)
                if edit["off"] == true
                    continue
                end
            end
            apply_edit!(args..., griditem, edit, dir_cache=dir_cache)
            griditem.edits[i] = JSON.json(edit)  # there can be updates to the parameters
        end
    end
    return nothing
end


"""Applies one edit to the image data."""
function apply_edit!(d::MatrixFloat, griditem::SpmGridItem, edit::AbstractDict; dir_cache::String="")::Nothing
    # get the function from the string

    key = edit["id"]
    if key ∉ keys(editing_entries["image"])
        @warn "Unknown edit id: $key"
        return nothing
    end

    func_name = editing_entries["image"][key]["function"]
    func = getfield(SpmImageTycoon, Symbol(func_name))

    default_pars = editing_entries["image"][key]["pars"]
    edit["pars"] = get_params(edit["pars"], default_pars)

    # apply the function
    n = haskey(edit, "n") ? edit["n"] : "-1"
    func(d, griditem, edit["pars"], n, dir_cache)

    return nothing
end


"""Applies one edit to the spectrum data."""
function apply_edit!(x_data::VectorFloat, y_data::VectorFloat, griditem::SpmGridItem, edit::AbstractDict; dir_cache::String="")::Nothing
    # get the function from the string

    key = edit["id"]
    if key ∉ keys(editing_entries["spectrum"])
        @warn "Unknown edit key: $key"
        return nothing
    end

    func_name = editing_entries["spectrum"][key]["function"]
    func = getfield(SpmImageTycoon, Symbol(func_name))

    default_pars = editing_entries["spectrum"][key]["pars"]
    edit["pars"] = get_params(edit["pars"], default_pars)

    # apply the function
    n = haskey(edit, "n") ? edit["n"] : "-1"
    func(x_data, y_data, griditem, edit["pars"], n, dir_cache)

    return nothing
end



function Gaussian(d::MatrixFloat, griditem::SpmGridItem, pars::AbstractDict, n::String, dir_cache::String)::Nothing
    s = pars["s"]
    ss = reverse(nm_to_px(griditem, size(d), s))

    d .= imfilter(d, Kernel.gaussian(ss))

    return nothing
end


function Laplacian(d::MatrixFloat, griditem::SpmGridItem, pars::AbstractDict, n::String, dir_cache::String)::Nothing
    d .= imfilter(d, Kernel.Laplacian())

    return nothing
end


function DoG(d::MatrixFloat, griditem::SpmGridItem, pars::AbstractDict, n::String, dir_cache::String)::Nothing
    s1 = pars["s1"]
    s2 = pars["s2"]
    ss1 = reverse(nm_to_px(griditem, size(d), s1))
    ss2 = reverse(nm_to_px(griditem, size(d), s2))
    l = round(Int, max(ss1..., ss2...)) * 4 + 1

    d .= imfilter(d, Kernel.DoG(ss1, ss2, (l, l)))

    return nothing
end


function LoG(d::MatrixFloat, griditem::SpmGridItem, pars::AbstractDict, n::String, dir_cache::String)::Nothing
    s = pars["s"]
    ss = reverse(nm_to_px(griditem, size(d), s))

    d .= imfilter(d, Kernel.LoG(ss))

    return nothing
end


function FTF(d::MatrixFloat, griditem::SpmGridItem, pars::AbstractDict, n::String, dir_cache::String)::Nothing
    pars["ps"] = reverse(size(d))  # pixel size of original image, in x/y order
    pars["mf"] = last.(rfftfreq.(pars["ps"])) # maximum frequency, in x/y order

    # replace NaNs with minumum value before doing the FFT (save their positions)
    # then, at the end, after the reverse FFT we could replace the previous NaN-positions with NaNs again
    # this, however, messes up the (next) FT of the images, so we will not set them to NaNs again
    nans = isnan.(d)
    dskip = skipnan(d)
    if isempty(dskip) # all NaNs
        return nothing
    end
    vmin = minimum(skipnan(d))
    d[nans] .= vmin

    F = rfft(d)
    
    norm_func = x -> x
    if haskey(pars, "s")
        if pars["s"] == "ln"
            del = eltype(d)(1e-16)
            norm_func = x -> Base.log(x + del)  # we add a small value to avoid taking the log of zero, `abs` is done in the `disp_fun` below
        elseif pars["s"] == "sq"
            norm_func = x -> sqrt(x)  #  `abs` is dont in the `disp_fun` below
        end
    end
    disp_func = x -> abs(x)
    if haskey(pars, "d")
        if pars["d"] == "r"
            disp_func = x -> abs(real(x))
        elseif pars["d"] == "i"
            disp_func = x -> abs(imag(x))
        end
    end

    F .= fftshift(F, 2)
    F_norm = @. norm_func(disp_func(F))  # save this to a file

    normalize01!(F_norm)
    # clamp01nan!(F_norm)
    im_arr = Gray.(F_norm)
    # im_arr = colorize(F_norm, griditem.colorscheme)
    fname = get_filename_edit(griditem.filename_display, "FT_$n")
    fname_abs = joinpath(
        get_dir_edits(dir_cache),
        fname
    )
    save(fname_abs, im_arr)

    if haskey(pars, "f") && haskey(pars, "r") && length(pars["r"]) > 0
        fac_x, fac_y = size(F, 2) / 1e6, size(F, 1) / 1e6  # the 1e6 is the export scale specified in the js file

        mask = zeros(size(F))

        if length(pars["r"]) % 2 == 1  # should never happen, though
            pop!(pars["r"])
        end
        for i in 1:2:length(pars["r"])
            (length(pars["r"][i]) === 2 && isa(pars["r"][i], Array)) || continue
            x_range = [pars["r"][i][1], pars["r"][i+1][1]] .* fac_x
            y_range = [pars["r"][i][2], pars["r"][i+1][2]] .* fac_y
            x_range = round.(Int, x_range) .+ 1  # convert to 1 based index
            y_range = round.(Int, y_range) .+ 1  # convert to 1 based index

            # check order
            if (x_range[2] < x_range[1])
                x_range[1], x_range[2] = x_range[2], x_range[1]
            end
            if (y_range[2] < y_range[1])
                y_range[1], y_range[2] = y_range[2], y_range[1]
            end

            # window
            nx, ny = x_range[2] - x_range[1] + 1, y_range[2] - y_range[1] + 1
            window_size = (ny, nx)
            if !haskey(pars, "w")
                w = ones(window_size)
                pars["w"] = ""
            elseif pars["w"] == "hn"
                w = DSP.Windows.hanning(window_size)
            elseif pars["w"] == "hm"
                w = DSP.Windows.hamming(window_size)
            elseif pars["w"] == "tk"
                w = DSP.Windows.tukey(window_size, 0.5)
            elseif pars["w"] == "cs"
                w = DSP.Windows.cosine(window_size)
            elseif pars["w"] == "lc"
                w = DSP.Windows.lanczos(window_size)
            elseif pars["w"] == "tr"
                w = DSP.Windows.triang(window_size)
            elseif pars["w"] == "ba"
                w = DSP.Windows.bartlett(window_size)
            elseif pars["w"] == "ga"
                w = DSP.Windows.gaussian(window_size, 0.4)
            elseif pars["w"] == "bh"
                w = DSP.Windows.bartlett_hann(window_size)
            elseif pars["w"] == "bl"
                w = DSP.Windows.blackman(window_size)
            elseif pars["w"] == "ka"
                w = DSP.Windows.kaiser(window_size, 3)
            else
                w = ones(window_size)
                pars["w"] = ""
            end

            haskey(pars, "wf") && (w .*= pars["wf"])

            # check bounds
            if all(x_range .< 1) || all(y_range .< 1)
                continue
            end
            if all(x_range .> size(F, 2)) || all(y_range .> size(F, 1))
                continue
            end
            
            if (x_range[1] < 1)
                w = @view w[:, 1-x_range[1]+1:end]
                x_range[1] = 1
            end
            if (x_range[2] > size(F, 2))
                w = @view w[:, 1:end-(x_range[2]-size(F, 2))]
                x_range[2] = size(F, 2)
            end
            if (y_range[1] < 1)
                w = @view w[1-y_range[1]+1:end, :]
                y_range[1] = 1
            end
            if (y_range[2] > size(F, 1))
                w = @view w[1:end-(y_range[2]-size(F, 1)), :]
                y_range[2] = size(F, 1)
            end
            
            mask[y_range[1]:y_range[2], x_range[1]:x_range[2]] .+= w
        end

        clamp!(mask, 0.0, 1.0)
        haskey(pars, "f") && (pars["f"] == "r") && (@. mask = 1.0 - mask)
        F .*= mask
    end

    d .= irfft(fftshift(F, 2), size(d, 1))
    # d[nans] .= NaN  # do not set as NaN again, see comment at the beginning of this function
    return nothing
end


function Gaussian(x::VectorFloat, y::VectorFloat, griditem::SpmGridItem, pars::AbstractDict, n::String, dir_cache::String)::Nothing
    s = pars["s"]
    y .= imfilter(y, Kernel.gaussian((s, )))

    return nothing
end


function diff1(x::VectorFloat, y::VectorFloat, griditem::SpmGridItem, pars::AbstractDict, n::String, dir_cache::String)::Nothing
    dy = diff(y)
    push!(dy, dy[end])
    y .= dy

    return nothing
end


