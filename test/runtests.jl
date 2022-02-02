using SpmImageTycoon
using Test

@testset "SpmImageTycoon.jl" begin
    # todo delete cache directory if exists
    w=tycoon(keep_alive=false, return_window=true)  # but do not load and save config json

    # do js tests etc
    # export openoffice presentation (odp)

    close(w)
    # delete cache directory and odp file

end
