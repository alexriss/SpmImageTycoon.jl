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
        edit = JSON.parse(edit_str)
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


"""converts and checks parameters corresponding to the given edit."""
function get_params(pars::Dict, default_pars::OrderedDict)::Dict
    res = Dict()
    for (k,v) in pars
        if haskey(default_pars, k)
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
            res[k] = v
        end
    end
    return res
end


"""Applies all edits to the image data."""
function apply_edits!(d::MatrixFloat, griditem::SpmGridItem)::Nothing
    for (i,edit) in enumerate(griditem.edits)
        edit = JSON.parse(edit)
        if "id" in keys(edit)
            if "off" in keys(edit)
                if edit["off"] == true
                    continue
                end
            end
            apply_edit!(d, griditem, edit)
            griditem.edits[i] = JSON.json(edit) # there can be updates to the parameters
        end
    end
    return nothing
end


"""Applies all edits to the spectrum data."""
function apply_edits!(x_data, y_data, griditem::SpmGridItem)::Nothing
    for (i,edit) in enumerate(griditem.edits)
        edit = JSON.parse(edit)
        if "id" in keys(edit)
            if "off" in keys(edit)
                if edit["off"] == true
                    continue
                end
            end
            apply_edit!(x_data, y_data, griditem, edit)
            griditem.edits[i] = JSON.json(edit) # there can be updates to the parameters
        end
    end
    return nothing
end


"""Applies one edit to the image data."""
function apply_edit!(d::MatrixFloat, griditem::SpmGridItem, edit::Dict)::Nothing
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
    func(d, griditem, edit["pars"])

    return nothing
end


"""Applies one edit to the spectrum data."""
function apply_edit!(x_data::VectorFloat, y_data::VectorFloat, griditem::SpmGridItem, edit::Dict)::Nothing
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
    func(x_data, y_data, griditem, edit["pars"])

    return nothing
end



function Gaussian(d::MatrixFloat, griditem::SpmGridItem, pars::Dict)::Nothing
    s = pars["s"]
    ss = reverse(nm_to_px(griditem, size(d), s))

    d .= imfilter(d, Kernel.gaussian(ss))

    return nothing
end


function Laplacian(d::MatrixFloat, griditem::SpmGridItem, pars::Dict)::Nothing
    d .= imfilter(d, Kernel.Laplacian())

    return nothing
end


function DoG(d::MatrixFloat, griditem::SpmGridItem, pars::Dict)::Nothing
    s1 = pars["s1"]
    s2 = pars["s2"]
    ss1 = reverse(nm_to_px(griditem, size(d), s1))
    ss2 = reverse(nm_to_px(griditem, size(d), s2))
    l = round(Int, max(ss1..., ss2...)) * 4 + 1

    d .= imfilter(d, Kernel.DoG(ss1, ss2, (l, l)))

    return nothing
end


function LoG(d::MatrixFloat, griditem::SpmGridItem, pars::Dict)::Nothing
    s = pars["s"]
    ss = reverse(nm_to_px(griditem, size(d), s))

    d .= imfilter(d, Kernel.LoG(ss))

    return nothing
end


function Gaussian(x::VectorFloat, y::VectorFloat, griditem::SpmGridItem, pars::Dict)::Nothing
    s = pars["s"]
    y .= imfilter(y, Kernel.gaussian((s, )))

    return nothing
end


function diff1(x::VectorFloat, y::VectorFloat, griditem::SpmGridItem, pars::Dict)::Nothing
    dy = diff(y)
    push!(dy, dy[end])
    y .= dy

    return nothing
end


