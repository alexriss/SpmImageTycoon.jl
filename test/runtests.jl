using SpmImageTycoon
using Test

import SpmImageTycoon.Blink.@js

include("results.jl")

FNAME_odp = "test_presentation.odp"

"""Delete old files."""
function delete_files(i = 1)::Nothing
    try
        if isdir("data/_spmimages_cache")
            rm("data/_spmimages_cache", recursive=true)
        end
        if isfile(FNAME_odp)
            rm(FNAME_odp)
        end
        if i > 1
            println(" ok.")
        end
    catch e
        if isa(e, Base.IOError)
            if i == 1 
                print("Can't delete old files. Retrying.")
            else
                print(".")
            end
            if i > 5
                throw(e)
            end
            sleep(1)
            delete_files(i+1)
        else
            throw(e)
        end
    end
    return nothing
end

"""Compare two dictionaries of items."""
function compare_dicts(dict1, dict2, tol=1e-6)
    for (k,v1) in dict1
        if k in ["created", "filename_display_last_modified"]  # these won't be the same
            continue
        end

        if !haskey(dict2, k)
            return false
        end
        v2 = dict2[k]

        if v1 == v2
            continue
        end
        if isa(v1, Dict)
            if !compare_dicts(v1, v2)
                return false
            end
        elseif isa(v1, AbstractArray)
            if !(length(v1) == length(v2))
                println("Not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
            if !all(abs.(v1 .- v2) .< tol)
                println("Not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        elseif isa(v1, String)
            if v1 != v2
                println("Not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        elseif isnan(v1)
            if !isnan(v2)
                println("Not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        elseif isa(v1, Number)
            if !(abs(v1 - v2) < tol)
                println("Not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        else
            if v1 != v2
                println("Not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        end
    end
    return true
end


"""Escape dots in a HTML-id, so it can be used in querySelectorAll."""
function escape_id(id::String)::String
    id = replace(id, "." => "\\.")
    id = replace(id, " " => "\\ ")
    return id
end

"""Escape dots in HTML-ids, so it can be used in querySelectorAll."""
function selector(ids::Vector{String})::String
    ids_ = ["#" * escape_id(id) for id in ids]
    return join(ids_, ",") 
end

"""Construct querySelector from id."""
function selector(id::String)::String
    return "#" * escape_id(id)
end

"""Get window.items from js."""
function get_items(sleeptime=1)
    sleep(sleeptime)
    return @js w window.items
end

"""Sends a key-press to js. Also modifiers can be included. E.g. `ctrl-a` or `ctrl-shift-a`."""
function send_key(k::String)
    s = split(k, "-")
    k = s[end]
    modifiers = s[1:end-1]
    @js w test_press_key($k, $modifiers)
    sleep(0.05)
end

"""Sends a key-press to js. Also modifiers can be included. E.g. `ctrl-a` or `ctrl-shift-a`."""
function send_key(k::AbstractArray)
    for k_ in k
        send_key(k_)
    end
end

"""Sends a mouse click to all elements set by the css selector."""
function send_click(sel::String)
    @js w test_click_mouse($sel)
    sleep(0.1)
end

"""Sends a double-click to all elements set by the css selector.
Does not seem to work so well."""
function send_double_click(sel::String)
    @js w test_dblclick_mouse($sel)
    sleep(0.1)
end

"""Hovers the mouse over all elements set by the css selector."""
function send_hover_mouse(sel::String)
    @js w test_hover_mouse($sel)
    sleep(0.1)
end



@testset "Loading" begin
    delete_files()

    global dir_data = abspath("data/")
    dir_cache = abspath("data/_spmimages_cache")

    global w = tycoon(keep_alive=false, return_window=true)  # in the test environment config is not loaded and saved

    global fnames_images = filter(endswith(".sxm"), readdir(dir_data))
    global fnames_spectra = filter(endswith(".dat"), readdir(dir_data))

    @js w load_directory($dir_data)

    items = get_items()
    @test compare_dicts(items, items1)

    @test length(items) == length(fnames_images) + length(fnames_spectra)
    @test isdir(dir_cache)

    fnames_images_generated = filter(endswith(".png"), readdir(dir_cache))
    fnames_spectra_generated = filter(endswith(".svg"), readdir(dir_cache))
    @test length(fnames_images_generated) == length(fnames_images)
    @test length(fnames_spectra_generated) == length(fnames_spectra)
end

@testset "Manipulating" begin
    selected = ["Image_002.sxm", "Image_004.sxm"]
    sel = selector(selected)
    send_click(sel)
    send_key(["b","b","B"])
    send_key(["i","p","p","P", "x"])  # "x" should have no effect

    send_key(["n"])

    selected = [f for f in fnames_spectra if startswith(f, "STS") || startswith(f, "Follow")]
    sel = selector(selected)
    send_click(sel)
    active = @js w get_active_element_ids()
    @test sort(active) == sort(selected)

    send_key(["x", "X", "c", "c", "Y", "y", "C", "c", "i", "i", "i", "i"])

    items = get_items()
    @test compare_dicts(items, items2)

    send_key("n")  # deselect all
    selected = ["Image_110.sxm", "Image_661.sxm", "Image_695.sxm", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)

    send_key(["b", "d", "d", "p", "p", "P", "b", "p"])

    items = get_items()
    @test compare_dicts(items, items3)
    
    send_key(["a", "p"])
    send_key(["a"])
    selected = ["Image_110.sxm", "Image_695.sxm", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key(["R"])

    items = get_items()
    @test compare_dicts(items, items4)
end

@testset "Copying and pasting" begin
    # copy and paste parameters
    send_key(["n"])
    selected = ["Image_002.sxm", "Image_004.sxm"]
    sel = selector(selected)
    send_click(sel)
    send_key(["ctrl-c"])
    send_key("n")  # deselect all
    selected = ["Image_110.sxm", "Image_661.sxm", "Image_695.sxm", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key(["ctrl-v"])

    # nothing should happen because the initial selection were two images (copy only workls from one image)
    items = get_items()
    @test compare_dicts(items, items4)

    send_key(["n"])
    selected = ["Image_004.sxm"]
    sel = selector(selected)
    send_click(sel)
    send_key(["ctrl-c"])
    send_key("n")  # deselect all
    selected = ["Image_695.sxm", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key(["ctrl-v"])

    items = get_items()
    @test compare_dicts(items, items5)

    # revert
    send_key(["R"])
    items = get_items()
    @test compare_dicts(items, items4)


    send_key("n")  # deselect all
    selected = ["Image_002.sxm", "Image_004.sxm"]
    sel = selector(selected)
    send_click(sel)

    # go into zoom view - copy should work in zoom view (despite two selected in grid view)
    selected = ["Image_004.sxm"]
    sel = selector(selected)
    send_hover_mouse(sel)
    send_key("z")  # switch to zoom view
    sleep(0.3)
    send_key(["ctrl-c"])
    send_key("z")  # back to grid view
    send_key("n")  # deselect all
    selected = ["Image_695.sxm", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key(["ctrl-v"])
    items = get_items()
    @test compare_dicts(items, items5)
end

@testset "Saving and Reloading" begin
    send_key(["ctrl-w"])
    sleep(1)
    @js w load_directory($dir_data)
    items = get_items()
    @test compare_dicts(items, items5)
end

@testset "Edge cases" begin
    # empty image
    send_key("n")  # deselect all
    selected = ["empty.sxm"]
    sel = selector(selected)
    send_click(sel)
    send_key(["b", "b", "b", "b", "b", "b", "b", "d", "d", "c", "c", "p", "p", "i", "R"])

    send_hover_mouse(sel)
    send_key("z")  # switch to zoom view
    send_key(["p"])
    sleep(0.3)
    send_key("z")  # back to grid view

    items = get_items()
    @test compare_dicts(items, items5)

    # todo: empty spectrum
end

@testset "Keywords" begin
    # todo
end

@testset "Rating" begin
    # todo
end

@testset "Virtual Copy" begin
    # todo
end

@testset "Filtering" begin
    # todo
end

@testset "Zoom view image" begin
    # todo 
end

@testset "Line profiles" begin
    # todo 
end

@testset "Zoom view spectrum" begin
    # todo 
end

@testset "Check update" begin
    send_click("#modal_about_check_update")
    sleep(0.5)
    no_new_version_hidden = @js w document.getElementById("modal_about_no_new_version").classList.contains("is-hidden")
    new_version_hidden = @js w document.getElementById("modal_about_new_version").classList.contains("is-hidden")
    unreleased_version_hidden = @js w document.getElementById("modal_about_unreleased_version").classList.contains("is-hidden")
    @test !(no_new_version_hidden && new_version_hidden && unreleased_version_hidden)
end

@testset "Export" begin
    send_key("n")  # deselect all, should then export all images
    @js w test_export_to($FNAME_odp)
    @test filesize(FNAME_odp) > 300e3  # for now we just make sure that there is a reasonable filesize

    # copy to clipboard
    selected = ["Image_695.sxm", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key("ctrl-E")
    sleep(0.2)
    @test clipboard() == "\"Image_695.sxm\", \"Z-Spectroscopy507.dat\""
end

@testset "Close" begin
    send_key(["ctrl-w"])
    # close(w)
    # delete_files()
end
