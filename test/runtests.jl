using SpmImageTycoon
using Test

import SpmImageTycoon.Blink.@js


function delete_files()::Nothing
    if isdir("data/_spmimages_cache")
        rm("data/_spmimages_cache", recursive=true)
    end
    if isfile("test_presentation.odp")
        rm("test_presentation.odp")
    end
    return nothing
end

function escape_id(id::String)::String
    return replace(id, "." => "\\.")
end

function selector(ids::Vector{String})::String
    ids_ = ["#" * escape_id(id) for id in ids]
    return join(ids_, ",") 
end

function selector(id::String)::String
    return "#" * escape_id(id)
end


@testset "Loading" begin
    delete_files()

    dir_data = abspath("data/")
    dir_cache = abspath("data/_spmimages_cache")

    global w = tycoon(keep_alive=false, return_window=true)  # in the test environment config is not loaded and saved

    global fnames_images = filter(endswith(".sxm"), readdir(dir_data))
    global fnames_spectra = filter(endswith(".dat"), readdir(dir_data))

    @js w load_directory($dir_data)

    items = @js w window.items

    @test length(items) == length(fnames_images) + length(fnames_spectra)
    @test isdir(dir_cache)

    fnames_images_generated = filter(endswith(".png"), readdir(dir_cache))
    fnames_spectra_generated = filter(endswith(".svg"), readdir(dir_cache))
    @test length(fnames_images_generated) == length(fnames_images)
    @test length(fnames_spectra_generated) == length(fnames_spectra)
end

@testset "Images" begin
    @show "Loading images"
    @show fnames_images
    select_images = fnames_images[1:3]
    sel = selector(select_images)
    @js w test_click_mouse($sel)
    @js w test_press_key("c")
    @js w test_press_key("c")
    @js w test_press_key("C")
    items = @js w window.items
    active = @js w get_active_element_ids()
    @test active == select_images
end

@testset "export" begin
    # export openoffice presentation (odp)
    @js w console.log(1)
end

@testset "close" begin
    # close(w)
    # delete_files()
end
