editing_entries = OrderedDict(
    "image" => OrderedDict(
        "G" => Dict(
            "name" => "Gaussian",
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
        "L" => Dict(
            "name" => "Laplacian",
            "type" => "table",
            "params" => OrderedDict(),
            "abbreviation" => "L",
            "function" => "Laplacian",
        ),
        "DoG" => Dict(
            "name" => "Difference of Gaussians",
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
        "LoG" => Dict(
            "name" => "Laplacian of Gaussian",
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
        "G" => Dict(
            "name" => "Gaussian",
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