editing_entries = OrderedDict(
    "image" => OrderedDict(
        "G" => Dict(
            "name" => "Gaussian",
            "type" => "table",
            "pars" => OrderedDict(
                "s" => Dict(
                    "type" => "float",
                    "name" => "&sigma;",
                    "default" => 0.10,
                    "step" => 0.01,
                    "min" => 0.0,
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
                    "default" => 0.10,
                    "step" => 0.01,
                    "min" => 0.0,
                    "unit" => "nm",
                ),
                "s2" => Dict(
                    "type" => "float",
                    "name" => "&sigma;<sub>2</sub>",
                    "default" => 1.00,
                    "step" => 0.01,
                    "min" => 0.0,

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
                    "default" => 0.10,
                    "step" => 0.01,
                    "min" => 0.0,
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
                    "default" => 0.10,
                    "step" => 0.01,
                    "min" => 0.0,
                    "unit" => "points",
                )
            ),
            "abbreviation" => "G",
            "function" => "Gaussian",
        ),
    )
)


MatrixFloat = Union{Matrix{Float32}, Matrix{Float64}}


"""Converts nm to pixels."""
function nm_to_px(griditem::SpmGridItem, points::Int, val::Real)::Float64
    return val * points / griditem.scansize[1]
end


"""Applies all edits to the image data."""
function apply_edits!(d::MatrixFloat, griditem::SpmGridItem)::Nothing
    for edit in griditem.edits
        edit = JSON.parse(edit)
        if "id" in keys(edit)
            if "off" in keys(edit)
                if edit["off"] == true
                    continue
                end
            end
            apply_edit!(d, griditem, edit)
        end
    end
    return nothing
end


"""Applies one edit to the image data."""
function apply_edit!(d::MatrixFloat, griditem::SpmGridItem, edit::Dict)::Nothing
    # get the function from the string

    key = edit["id"]
    if key ∉ keys(editing_entries["image"])
        @warn "Unknown edit key: $key"
        return nothing
    end

    func_name = editing_entries["image"][key]["function"]
    func = getfield(SpmImageTycoon, Symbol(func_name))

    default_pars = editing_entries["image"][key]["pars"]

    # apply the function
    func(d, griditem, edit["pars"], default_pars)

    return nothing
end


function Gaussian(d::MatrixFloat, griditem::SpmGridItem, pars::Dict, default_pars::OrderedDict)::Nothing
    s = pars["s"]
    if !isa(s, Real)
        try
            s = parse(Float64, s)
        catch
            s = default_pars["s"]["default"]
        end
    end
    s = nm_to_px(griditem, size(d, 1), s)

    d .= imfilter(d, Kernel.gaussian(s))

    return nothing
end


function Laplacian(d::MatrixFloat, griditem::SpmGridItem, pars::Dict, default_pars::OrderedDict)::Nothing
    d .= imfilter(d, Kernel.Laplacian())

    return nothing
end


function DoG(d::MatrixFloat, griditem::SpmGridItem, pars::Dict, default_pars::OrderedDict)::Nothing
    s1 = pars["s1"]
    s2 = pars["s2"]
    if !isa(s1, Real)
        try
            s1 = parse(Float64, s1)
        catch
            s1 = default_pars["s1"]["default"]
        end
    end
    if !isa(s2, Real)
        try
            s2 = parse(Float64, s2)
        catch
            s2 = default_pars["s2"]["default"]
        end
    end
    s1 = nm_to_px(griditem, size(d, 1), s1)
    s2 = nm_to_px(griditem, size(d, 1), s2)

    d .= imfilter(d, Kernel.DoG((s1, s2)))

    return nothing
end


function LoG(d::MatrixFloat, griditem::SpmGridItem, pars::Dict, default_pars::OrderedDict)::Nothing
    s = pars["s"]
    if !isa(s, Real)
        try
            s = parse(Float64, s)
        catch
            s = default_pars["s"]["default"]
        end
    end
    s = nm_to_px(griditem, size(d, 1), s)

    d .= imfilter(d, Kernel.LoG(s))

    return nothing
end

