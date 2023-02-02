editing_entries = OrderedDict(
    "image" => OrderedDict(
        "G" => Dict(
            "name" => "Gaussian",
            "type" => "table",
            "params" => OrderedDict(
                "s" => Dict(
                    "name" => "&sigma;",
                    "default" => 0.10,
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
                "s1" => Dict(
                    "name" => "&sigma;<sub>1</sub>",
                    "default" => 0.10,
                    "step" => 0.01,
                    "unit" => "nm",
                ),
                "s2" => Dict(
                    "name" => "&sigma;<sub>2</sub>",
                    "default" => 1.00,
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
                "s" => Dict(
                    "name" => "&sigma;",
                    "default" => 0.10,
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
                "s" => Dict(
                    "name" => "&sigma;",
                    "default" => 0.10,
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