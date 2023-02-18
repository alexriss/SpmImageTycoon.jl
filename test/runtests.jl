using Test
t0 = time()
using SpmImageTycoon
t1 = time()
using Printf
using ImageIO
using Images
using DataStructures: OrderedDict
import Dates
import Base: _sizeof_uv_fs, uv_error

import SpmImageTycoon.Blink.@js

include("results.jl")
include("functions.jl")


# need to be global, so we can call it from within the main SpmImageTycoon module (for tests of the compiled version)
global FNAME_odp = "test_presentation.odp"
global DIR_db_old = "old_db/"
global DIR_data = "data/"
global DIR_cache = "data/_spmimages_cache"

global timings = OrderedDict{String, Float64}()

global timings["import"] = t1 - t0

@testset "Parse directory" begin
    delete_files()

    global dir_data = abspath(DIR_data)
    dir_cache = abspath(DIR_cache)

    t0 = time()
    global w = tycoon(keep_alive=false, return_window=true)  # in the test environment config is not loaded and saved
    t1 = time()

    global fnames_images = filter(endswith(".sxm"), readdir(dir_data))
    global fnames_spectra = filter(endswith(".dat"), readdir(dir_data))

    @js w load_directory($dir_data)
    t2 = time()

    items = get_items()
    @test compare_dicts(items, items1)

    @test length(items) == length(fnames_images) + length(fnames_spectra)
    @test isdir(dir_cache)

    fnames_images_generated = filter(endswith(".png"), readdir(dir_cache))
    fnames_spectra_generated = filter(endswith(".svg"), readdir(dir_cache))
    @test length(fnames_images_generated) == length(fnames_images)
    @test length(fnames_spectra_generated) == length(fnames_spectra)

    global timings["startup"] = t1 - t0
    global timings["load directory"] = t2 - t1
end

@testset "Convert old database" begin
    griditems = SpmImageTycoon.load_all(DIR_db_old, nothing)
    items_loaded = Dict{String,Any}()
    for item in griditems
        # item is stored as a Pair{String,SpmGridItem}
        k = item[1]
        griditem = item[2]
        d = Dict(string(key) => getfield(griditem, key) for key in propertynames(griditem))
        items_loaded[k] = d
    end
    @test compare_dicts(items_loaded, items_old_db)
end

@testset "Manipulation" begin
    selected = ["Image_002.sxm", "Image_004.sxm"]
    sel = selector(selected)
    send_click(sel)
    t0 = time()
    send_key(["b"])
    t1 = time()
    send_key(["b","B"])
    t2 = time()
    send_key(["p"])
    t3 = time()
    send_key(["i"])
    t4 = time()
    send_key(["p","P", "x"])  # "x" should have no effect

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

    global timings["background correction"] = t1 - t0
    global timings["background correction (two times)"] = t2 - t1
    global timings["color scheme"] = t3 - t2
    global timings["invert color scheme"] = t4 - t3
end

@testset "Copy and paste" begin
    # copy and paste parameters
    send_key(["n"])
    selected = ["Image_002.sxm", "Image_004.sxm"]
    sel = selector(selected)
    send_click(sel)

    # select multiple, and mouse hovering on one of them, should copy
    selected = ["Image_004.sxm"]
    sel = selector(selected)
    send_hover_mouse(sel)
    send_key(["ctrl-c"])
    copy_from = @js w window.last_copy_from
    @test copy_from == "Image_004.sxm"

    # multiple selectec, but mouse not hovering on one of them - should not copy
    sleep(0.5)
    selected = ["Image_695.sxm"]
    sel = selector(selected)
    send_hover_mouse(sel)
    sleep(0.5)
    # send clicks twice, to select and de-select (hover does not seem to work on github actions)
    # also do the hover again
    send_click(sel)
    send_click(sel)
    send_hover_mouse(sel)
    sleep(0.5)
    send_key(["ctrl-c"])
    copy_from = @js w window.last_copy_from
    @test copy_from == ""

    send_key("n")  # deselect all

    selected = ["Image_110.sxm", "Image_661.sxm", "Image_695.sxm", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)

    items = get_items()
    @test compare_dicts(items, items4)

    send_key(["ctrl-v"])

    # nothing should happen because the initial selection were two images (copy only works from one image)
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

@testset "Save and reload" begin
    send_key(["ctrl-w"])
    sleep(1)

    # check saving behavior - db file should be only saved when there are changes
    mtime_db = mtime(joinpath(DIR_cache, "db.jld2"))
    mtime_bak1 = mtime(joinpath(DIR_cache, "db_backup_1.jld2"))
    mtime_bak2 = mtime(joinpath(DIR_cache, "db_backup_2.jld2"))
    mtime_bak3 = mtime(joinpath(DIR_cache, "db_backup_3.jld2"))
    mtime_bak4 = mtime(joinpath(DIR_cache, "db_backup_4.jld2"))

    # the db file, as well as backups should exist
    @test mtime_db > 0
    @test mtime_bak1 > 0
    @test mtime_bak2 > 0
    @test mtime_bak3 > 0
    @test mtime_bak4 > 0
    @test (mtime_db - mtime_bak1) < 10

    # reopen directory
    t0 = time()
    @js w load_directory($dir_data)
    t1 = time()
    items = get_items()
    @test compare_dicts(items, items5)

    # since we just opened, this should save (without `force`)
    @js w save_all()
    sleep(0.5)
    mtime_db_2 = mtime(joinpath(DIR_cache, "db.jld2"))
    @test mtime_db_2 > mtime_db
    mtime_bak1_ = mtime(joinpath(DIR_cache, "db_backup_1.jld2"))
    mtime_bak3_ = mtime(joinpath(DIR_cache, "db_backup_3.jld2"))
    # there should be no change in backup files
    @test mtime_bak1_ == mtime_bak1
    @test mtime_bak3_ == mtime_bak3

    mtime_bak1_set = mtime_bak1 - 2 * 3600
    mtime_bak3_set = mtime_bak3 - 40 * 3600
    setmtime(joinpath(DIR_cache, "db_backup_1.jld2"), mtime_bak1_set)
    setmtime(joinpath(DIR_cache, "db_backup_3.jld2"), mtime_bak3_set)

    # this should not save, since there were no changes
    @eval SpmImageTycoon griditems_last_changed -= 1000.0  # we could also sleep for a while, but this is faster (we need the eval to assign vars in other modules)
    @js w save_all()
    sleep(0.5)
    mtime_db_3 = mtime(joinpath(DIR_cache, "db.jld2"))
    mtime_bak1_ = mtime(joinpath(DIR_cache, "db_backup_1.jld2"))
    mtime_bak3_ = mtime(joinpath(DIR_cache, "db_backup_3.jld2"))
    @test mtime_db_2 ≈ mtime_db_3
    @test (mtime_bak1_ - mtime_bak1_set) < 1e-3  # should be the same as before - but the set-operation is not completely precise
    @test (mtime_bak3_ - mtime_bak3_set) < 1e-3

    # this should save, since we force it
    t2 = time()
    @js w save_all(false, true)
    t3 = time()
    sleep(0.5)
    mtime_db_4 = mtime(joinpath(DIR_cache, "db.jld2"))
    mtime_bak1_ = mtime(joinpath(DIR_cache, "db_backup_1.jld2"))
    mtime_bak3_ = mtime(joinpath(DIR_cache, "db_backup_3.jld2"))
    @test mtime_db_4 > mtime_db_3
    @test (mtime_bak1_ - mtime_db_4) < 10
    @test (mtime_bak3_ - mtime_db_4) < 10

    global timings["load directory"] = t1 - t0
    global timings["save"] = t3 - t2
end

@testset "Edge cases" begin
    # empty image
    send_key("n")  # deselect all
    selected = ["empty.sxm"]
    sel = selector(selected)
    send_click(sel)
    send_key(["b", "b", "b", "b", "b", "b", "b", "d", "d", "c", "c", "p", "p", "i", "R"])

    view = @js w get_view()
    @test view == "grid"

    send_hover_mouse(sel)
    send_key("z")  # switch to zoom view
    view = @js w get_view()
    if view != zoom
        @js w toggle_imagezoom("zoom", "empty.sxm")
    end
    sleep(0.3)

    send_key(["p"])
    sleep(0.3)

    last_sel = @js w window.image_info_id
    view = @js w get_view()
    @test last_sel == "empty.sxm"
    @test view == "zoom"

    send_key("z")  # back to grid view
    view = @js w get_view()
    @test view == "grid"

    items = get_items()
    @test compare_dicts(items, items5)

    # todo: empty spectrum
end

@testset "Keywords" begin
    # todo
end

@testset "Rating" begin
    send_key("n")  # deselect all
    selected = ["Image_002.sxm", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key(["4"])
    sleep(5)

    send_key("n")  # deselect all
    selected = ["Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key(["2"])

    send_key("n")  # deselect all
    selected = ["Image_398.sxm"]
    sel = selector(selected)
    send_click(sel)
    send_hover_mouse(sel)
    send_key("z")  # switch to zoom view
    view = @js w get_view()
    @test view == "zoom"
    send_key("1")
    sleep(0.3)
    send_key("z")  # back to grid view
    view = @js w get_view()
    @test view == "grid"

    items = get_items()
    @test compare_dicts(items, items6)
end

@testset "Editing" begin
    send_key("n")  # deselect all
    view = @js w get_view()
    @test view == "grid"

    selected = ["Image_212.sxm"]
    sel = selector(selected)
    send_click(sel)
    send_hover_mouse(sel)
    sleep(0.5)
    last_sel = @js w window.image_info_id
    if (last_sel != "Image_212.sxm")
        send_click(sel)
        send_hover_mouse(sel, send_event=false)
        sleep(0.5)
    end
    last_sel = @js w window.image_info_id
    @test last_sel == "Image_212.sxm"

    send_key("z")  # switch to zoom view
    sleep(0.5)
    view = @js w get_view()
    if (view != "zoom")  # sometimes this does not work on github CI
        @js w toggle_imagezoom("zoom", "Image_212.sxm")
    end
    last_sel = @js w window.image_info_id
    view = @js w get_view()
    @test last_sel == "Image_212.sxm"
    @test view == "zoom"
    
    send_key("t")
    sleep(2)

    change_value("#editing_entry_main_channel", "Current")
    change_value("#editing_entry_main_direction", "backward")
    change_value("#editing_entry_main_background", "plane")

    change_value("#editing_entry_add", "LoG")
    change_value("#editing_entry_add", "Laplacian")
    change_value("#editing_entry_add", "Gaussian")
    change_value("#editing_entry_add", "DoG")

    change_value(".editing_entry:last-child .editing_entry_active", false)
    change_value(".editing_entry .editing_entry_par_input", 0.2, [1])
    change_value(".editing_entry .editing_entry_par_input", 0.2, [2])
    change_value(".editing_entry .editing_entry_par_input", -2, [2])

    items = get_items()
    @test compare_dicts(items, items7)

    sleep(1)
    im = load(joinpath(DIR_cache, "Image_212.png"))
    @test im[10,9] ≈ RGB{N0f8}(0.839,0.424,0.424)
    @test im[78,8] ≈ RGB{N0f8}(0.847,0.427,0.416)
    @test im[3,6] ≈ RGB{N0f8}(0.855,0.431,0.408)
    @test im[23,33] ≈ RGB{N0f8}(0.984,0.624,0.239)
    @test im[90,78] ≈ RGB{N0f8}(0.851,0.427,0.412)

    send_key(["ArrowRight", "ArrowRight"])  # move to "Z-Spectroscopy__012.dat"
    sleep(3)
    last_sel = @js w window.image_info_id
    view = @js w get_view()
    @test view == "zoom"
    @test last_sel == "Z-Spectroscopy__012.dat"

    change_value("#editing_entry_main_channel", "Current")
    change_value("#editing_entry_main_background", "linear")
    change_value("#editing_entry_add", "G")
    change_value("#editing_entry_add", "dy")

    sleep(1)
    svg = read(joinpath(DIR_cache, "Z-Spectroscopy__012.svg"), String)
    @test count("<polyline", svg) == 2
    @test occursin("95.2 48.82,96.08 49.61,95.96 50.39,96.11 51.18", svg)
    @test occursin(",97.33 88.98,99.39 89.76,99.18 90.55,97.8 91.34,94.73 92.13,92.0 92.91,", svg)

    send_key("z")  # back to grid view
end

@testset "Virtual Copy" begin
    send_key("n")  # deselect all
    selected = ["Image_695.sxm", "Z-Spectroscopy507.dat", "Z-Spectroscopy__012.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key(["&"])
    sleep(2)

    send_key("n")  # deselect all
    selected = ["Image_695.sxm_1", "Z-Spectroscopy507.dat_1"]
    send_click(sel)
    send_key(["b", "b", "x", "y", "P", "P", "P", "x", "y"])
    sleep(1)

    send_key("n")  # deselect all
    selected = ["Image_695.sxm_1", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key(["&"])

    items = get_items()
    @test compare_dicts(items, items8)

    send_key("n")  # deselect all
    selected = ["Image_695.sxm_1"]
    sel = selector(selected)
    send_click(sel)
    send_key(["shift-Delete"])

    items = get_items()
    items8_del = copy(items8)
    delete!(items8_del, "Image_695.sxm_1")
    @test compare_dicts(items, items8_del)

    # reload directory
    send_key(["ctrl-w"])
    sleep(1)
    @js w load_directory($dir_data)
    sleep(1)
    @test compare_dicts(items, items8_del)
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
    sleep(0.8)
    no_new_version_hidden = @js w document.getElementById("modal_about_no_new_version").classList.contains("is-hidden")
    new_version_hidden = @js w document.getElementById("modal_about_new_version").classList.contains("is-hidden")
    unreleased_version_hidden = @js w document.getElementById("modal_about_unreleased_version").classList.contains("is-hidden")
    @test !(no_new_version_hidden && new_version_hidden && unreleased_version_hidden)
end

@testset "Export" begin
    send_key("n")  # deselect all, should then export all images
    t0 = time()
    @js w test_export_to($FNAME_odp)
    t1 = time()
    @test filesize(FNAME_odp) > 300e3  # for now we just make sure that there is a reasonable filesize

    # copy to clipboard
    selected = ["Image_695.sxm", "Z-Spectroscopy507.dat"]
    sel = selector(selected)
    send_click(sel)
    send_key("ctrl-E")
    sleep(0.2)

    # clip = clipboard()   # does not work in all environments
    clip = @js w getClipboard()
    @test clip == "\"Image_695.sxm\", \"Z-Spectroscopy507.dat\""

    global timings["export"] = t1 - t0
end

@testset "Close" begin
    mtime_db = mtime(joinpath(DIR_cache, "db.jld2"))
    send_key(["ctrl-w"])
    sleep(0.5)

    # upon closing, the db should be saved
    mtime_db_2 = mtime(joinpath(DIR_cache, "db.jld2"))
    @test mtime_db_2 > mtime_db

    # send_key(["alt-F4"])
    # delete_files()
end


# timings
l = maximum(length.(keys(timings)))
s = rpad("Timings", l, " ")
printstyled("$s | seconds\n", bold=true)
for (k, v) in timings
    local s = rpad(k, l, " ")
    sv =  @sprintf "%7.2f" v
    println("$s | $sv")
end
