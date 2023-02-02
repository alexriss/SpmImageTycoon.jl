editing_entries = OrderedDict(
    "image" => OrderedDict(
        "Gaussian" => Dict(
            "type" => "table",
            "params" => OrderedDict(
                "sigma" => Dict(
                    "default" => 0.1,
                    "step" => 0.01,
                    "unit" => "nm",
                )
            ),
            "abbreviation" => "G",
            "function" => "Gaussian",
        ),
        "Laplacian" => Dict(
            "type" => "table",
            "params" => OrderedDict(),
            "abbreviation" => "L",
            "function" => "Laplacian",
        ),
        "Difference of Gaussians" => Dict(
            "type" => "table",
            "params" => OrderedDict(
                "sigma<sub>1</sub>" => Dict(
                    "default" => 0.1,
                    "step" => 0.01,
                    "unit" => "nm",
                ),
                "sigma<sub>2</sub>" => Dict(
                    "default" => 1.0,
                    "step" => 0.01,
                    "unit" => "nm",
                )
            ),
            "function" => "DoG",
            "abbreviation" => "DoG",
        ),
        "Laplacian of Gaussian" => Dict(
            "type" => "table",
            "params" => OrderedDict(
                "sigma" => Dict(
                    "default" => 0.1,
                    "step" => 0.01,
                    "unit" => "nm",
                )
            ),
            "abbreviation" => "LoG",
            "function" => "LoG",
        ),
    ),

    "spectrum" => OrderedDict(
        "Gaussian" => Dict(
            "type" => "table",
            "params" => OrderedDict(
                "sigma" => Dict(
                    "default" => 0.1,
                    "step" => 0.01,
                    "unit" => "points",
                )
            ),
            "abbreviation" => "G",
            "function" => "Gaussian",
        ),
    )
)



# call functions from strings like that
#
# julia> fn = "time"
# "time"

# julia> Symbol(fn)
# :time

# julia> getfield(Main, Symbol(fn))
# time (generic function with 2 methods)

# julia> getfield(Main, Symbol(fn))()
# 1.448981716732318e9