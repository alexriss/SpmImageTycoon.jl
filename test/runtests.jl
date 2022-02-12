using SpmImageTycoon
using Test
import Dates
import Base: _sizeof_uv_fs, uv_error

import SpmImageTycoon.Blink.@js

include("results.jl")
include("functions.jl")


FNAME_odp = "test_presentation.odp"
DIR_db_old = "old_db/"
DIR_data = "data/"
DIR_cache = "data/_spmimages_cache"


@testset "Parse directory" begin
    delete_files()

    global dir_data = abspath(DIR_data)
    dir_cache = abspath(DIR_cache)

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
    selected = ["Image_695.sxm"]
    sel = selector(selected)
    send_hover_mouse(sel)
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
    @js w load_directory($dir_data)
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
    @js w save_all(false, true)
    sleep(0.5)
    mtime_db_4 = mtime(joinpath(DIR_cache, "db.jld2"))
    mtime_bak1_ = mtime(joinpath(DIR_cache, "db_backup_1.jld2"))
    mtime_bak3_ = mtime(joinpath(DIR_cache, "db_backup_3.jld2"))
    @test mtime_db_4 > mtime_db_3
    @test (mtime_bak1_ - mtime_db_4) < 10
    @test (mtime_bak3_ - mtime_db_4) < 10
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

    # clip = clipboard()   # does not work in all environments
    clip = @js w getClipboard()
    @test clip == "\"Image_695.sxm\", \"Z-Spectroscopy507.dat\""
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
