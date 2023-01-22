module SpmImageTycoon

using Blink
using CodecZlib
using ColorSchemes
using DataFrames
using DataStructures: OrderedDict
using Dates
using Images
using ImageIO
using JLD2
using JSExpr
using JSON
using NaturalSort
using SnoopPrecompile
using SpmImages
using SpmSpectroscopy
using StatsBase
using TOML

export SpmGridItem, tycoon

const VERSION = VersionNumber(TOML.parsefile(joinpath(@__DIR__, "../Project.toml"))["version"]) 


@enum SpmGridItemType SpmGridImage SpmGridSpectrum

# entries for SPM images and SPM spectra
mutable struct SpmGridItem_v129
    id::String                                 # id (will be filename and suffixes for virtual copies)
    type::SpmGridItemType                      # type of the griditem
    filename_original::String                  # original filename (.sxm for images or .dat for spectra)
    created::DateTime                          # file creation date
    last_modified::DateTime                    # file last modified date
    recorded::DateTime                         # date recorded
    filename_display::String                   # generated png or svg image
    filename_display_last_modified::DateTime   # png/svg image last modified
    channel_name::String                       # channel name (" bwd" indicates backward direction)
    channel_unit::String                       # unit for the respective channel
    channel2_name::String                      # xaxis channel name for spectra
    channel2_unit::String                      # xaxis unit for spectra
    scansize::Vector{Float64}                  # scan size in physical units, not used for spectra
    scansize_unit::String                      # scan size unit
    center::Vector{Float64}                    # center of scan frame or position of spectrum (in scansize_units - typically in nm) 
    angle::Float64                             # scan angle (in degrees), not used for spectra
    scan_direction::Int                        # scan direction (0=down, 1=up), for spectra 0=forward, 1=backward, 2=both

    bias::Float64                              # Bias in V
    z_feedback::Bool                           # feedback controller on/off
    z_feedback_setpoint::Float64               # feedback setpoint
    z_feedback_setpoint_unit::String           # feedback setpoint unit
    z::Float64                                 # Z position in m
    points::Int64                              # number of points in spectrum

    comment::String                            # comment in the file
    background_correction::String              # type of background correction used
    colorscheme::String                        # color scheme
    channel_range::Vector{Float64}             # min/max of current channel (for spectra this contains the min/max of channel and channel2)
    channel_range_selected::Vector{Float64}    # selected min/max for current channel
    filters::Vector{String}                    # array of filters used (not implemented yet)
    keywords::Vector{String}                   # keywords
    rating::Int64                              # rating (0 to 5 stars)
    status::Int64                              # status, i.e. 0: normal, -1: deleted by user, -2: deleted on disk (not  fully implemented yet)
    virtual_copy::Int64                        # specifies whether this is a virtual copy, i.e. 0: original image, >=1 virtual copies (not implemented yet)

    SpmGridItem_v129(; id="", type=SpmGridImage, filename_original="", created=DateTime(-1), last_modified=DateTime(-1), recorded=DateTime(-1),
        filename_display="", filename_display_last_modified=DateTime(-1),  # for non-excisting files mtime will give 0, so we set it to -1 here
        channel_name="", channel_unit="", channel2_name="", channel2_unit="",
        scansize=[], scansize_unit="nm", center=[], angle=0, scan_direction=0,
        bias=0, z_feedback=false, z_feedback_setpoint=0, z_feedback_setpoint_unit="", z=0.0, points=0,
        comment="", background_correction="none", colorscheme="gray",
        channel_range=[], channel_range_selected=[], filters=[], keywords=[], rating=0, status=0, virtual_copy=0) =
    new(id, type, filename_original, created, last_modified, recorded,
        filename_display, filename_display_last_modified,
        channel_name, channel_unit, channel2_name, channel2_unit,
        scansize, scansize_unit, center, angle, scan_direction,
        bias, z_feedback, z_feedback_setpoint, z_feedback_setpoint_unit, z, points,
        comment, background_correction, colorscheme,
        channel_range, channel_range_selected, filters, keywords, rating, status, virtual_copy)
end
SpmGridItem = SpmGridItem_v129


include("config.jl")
include("cache.jl")
include("helper_functions.jl")
include("image_functions.jl")
include("spectrum_functions.jl")
include("export.jl")
include("event_handlers.jl")
include("db_functions.jl")


exit_tycoon = false  # if set to true, then keep-alive loop will end
cancel_sent = false  # user can cancel load-directory operation
griditems_last_saved = 0.  # time of last save of griditems
griditems_last_changed = 0.  # time of last (potential) change of griditems - we do not keep track of actual changes, but only if certain events happen
griditems_lock = ReentrantLock()

Precompiling = false


"""sets keywords"""
function set_keywords!(ids::Vector{String}, dir_data::String, griditems::Dict{String,SpmGridItem}, mode::String, keywords::Vector{String})
    for id in ids
        if mode == "add"
            for keyword in keywords
                if keyword ∉ griditems[id].keywords
                    push!(griditems[id].keywords, keyword)
                end
            end
        elseif mode == "remove"
            filter!(k -> k ∉ keywords, griditems[id].keywords)
        else  # set
            griditems[id].keywords = keywords
        end
        sort!(griditems[id].keywords)
    end
    return nothing
end


"""returns a subset of the dictionary parsed_images. this can then be passed to the js"""
function get_subset(griditems::Dict{String, SpmGridItem}, ids::Vector{String})::OrderedDict{String, SpmGridItem}
    griditems_sub = OrderedDict{String, SpmGridItem}()
    map(ids) do id
        griditems_sub[id] = griditems[id]
    end
    return griditems_sub
end


"""gets a dictionary "original_id" => (array of virtual copies) with all virtual copies in griditems"""
function get_virtual_copies_dict(griditems::Dict{String, SpmGridItem})::Dict{String,Array{SpmGridItem}}
    virtual_copies = filter(x -> last(x).virtual_copy > 0, griditems)
    virtual_copies_dict = Dict{String, Array{SpmGridItem}}()  # create a dict for quick lookup
    for virtual_copy in values(virtual_copies)
        id_original = virtual_copy.filename_original
        if !haskey(virtual_copies_dict, id_original)
            virtual_copies_dict[id_original] = Array{SpmGridItem}(undef, 0);
        end
        push!(virtual_copies_dict[id_original], virtual_copy)
    end

    return virtual_copies_dict
end


"""gets the virtual copies that have been created for id. Returns an array of SpmGridItem"""
function get_virtual_copies(griditems::Dict{String, SpmGridItem}, id::String)::Array{SpmGridItem}
    virtual_copies = filter(x -> last(x).filename_original==id && last(x).virtual_copy > 0, griditems)
    return collect(values(virtual_copies))
end


"""Generates a new unique id that is not yet present in griditems by appending numbers to the given id"""
function get_new_id(griditems::Dict{String, SpmGridItem},id_original::String)::Tuple{String, Int}
    id = id_original
    i = 1
    while true
        id = "$(id_original)_$i"
        if !haskey(griditems, id)
            break
        end
        i += 1
    end
    return id, i
end


"""Generates the display filename for `griditem`."""
function get_filename_display(griditem::SpmGridItem, suffix::String="")::String
    base = splitext(griditem.filename_original)[1] * suffix
    if griditem.type == SpmGridSpectrum
        filename_display = "$(base).svg"
    else
        filename_display = "$(base).png"
    end
    
    return filename_display
end


"""Returns the scan range of all images. Returns bottom left and top right corner coordinates."""
function get_scan_range(griditems::Dict{String, SpmGridItem})::Tuple{Vector{Float64},Vector{Float64}}
    if length(griditems) == 0
        return [0.,0.], [0.,0.]
    end

    c = first(values(griditems)).center
    min_max_corners_x = [c[1], c[1]]
    min_max_corners_y = [c[2], c[2]]
    for img in values(griditems)
        if img.virtual_copy > 0 || img.status < 0
            continue
        end

        if img.type == SpmGridSpectrum
            min_max_corners_x = extrema([
                img.center[1],
                min_max_corners_x...
            ])
            min_max_corners_y = extrema([
                img.center[2],
                min_max_corners_y...
            ])
        else
            cosangle = cosd(img.angle)
            sinangle = sind(img.angle)
            w_half, h_half = img.scansize / 2
            min_max_corners_x = extrema([
                img.center[1] + w_half * cosangle - h_half * sinangle,
                img.center[1] - w_half * cosangle - h_half * sinangle,
                img.center[1] - w_half * cosangle + h_half * sinangle,
                img.center[1] + w_half * cosangle + h_half * sinangle,
                min_max_corners_x...
            ])

            min_max_corners_y = extrema([
                img.center[2] + w_half * sinangle + h_half * cosangle,
                img.center[2] - w_half * sinangle + h_half * cosangle,
                img.center[2] - w_half * sinangle - h_half * cosangle,
                img.center[2] + w_half * sinangle - h_half * cosangle,
                min_max_corners_y...
            ])
        end
    end
    bottomleft = [min_max_corners_x[1], min_max_corners_y[1]]
    topright = [min_max_corners_x[2], min_max_corners_y[2]]

    return bottomleft, topright
end


"""Cycles the channel, switches direction (backward/forward), changes background correction, changes colorscheme, or inverts colorscheme
for the images/spectra specified by ids. The type of change is specified by the argument "what".
The argument "jump" specifies whether to cycle backward or forward (if applicable).
The argument "full_resolution" specifies whether the images will be served in full resolution or resized to a smaller size.
Modifies the griditems array."""
function change_griditem!(griditems::Dict{String,SpmGridItem}, ids::Vector{String}, dir_data::String, what::String, jump::Int, full_resolution::Bool)::Nothing
    dir_cache = get_dir_cache(dir_data)
    Threads.@threads for id in ids
        filename_original_full = joinpath(dir_data, griditems[id].filename_original)
        if griditems[id].type == SpmGridImage
            item = load_image_memcache(filename_original_full)
        elseif griditems[id].type == SpmGridSpectrum
            item = load_spectrum_memcache(filename_original_full)
        else
            println("Unknown type: ", griditems[id].type)  # this should never happen, though
            continue
        end

        # multiple dispatch for update functions
        if what == "channel"
            next_channel_name!(griditems[id], item, jump)
        elseif what == "channel2"
            next_channel2_name!(griditems[id], item, jump)
        elseif what == "direction"
            next_direction!(griditems[id], item)
        elseif what == "background_correction"
            next_background_correction!(griditems[id], item, jump)
        elseif what == "colorscheme"
            next_colorscheme!(griditems[id], item, jump)
        elseif what == "inverted"
            next_invert!(griditems[id], item)
        else
            println("Unknown property to change: ", what)  # this should never happen, though
            return nothing
        end

        # update the image or spectrum
        if griditems[id].type == SpmGridImage
            resize_to_ = full_resolution ? 0 : resize_to
            create_image!(griditems[id], item, resize_to=resize_to, base_dir=dir_cache)    
        elseif griditems[id].type == SpmGridSpectrum
            create_spectrum!(griditems[id], item, base_dir=dir_cache)
        end
    end
    return nothing
end


"""Resets basic image/spectrum parameters to their default values"""
function reset_griditem!(griditems::Dict{String,SpmGridItem}, ids::Vector{String}, dir_data::String, full_resolution::Bool)::Nothing
    dir_cache = get_dir_cache(dir_data)
    Threads.@threads for id in ids
        filename_original_full = joinpath(dir_data, griditems[id].filename_original)

        if griditems[id].type == SpmGridImage
            item = load_image_memcache(filename_original_full)
        elseif griditems[id].type == SpmGridSpectrum
            item = load_spectrum_memcache(filename_original_full)
        else
            println("Unknown type: ", griditems[id].type)  # this should never happen, though
            continue
        end
    
        changed = reset_default!(griditems[id], item)

        # update the image or spectrum
        if changed
            if griditems[id].type == SpmGridImage
                resize_to_ = full_resolution ? 0 : resize_to
                create_image!(griditems[id], item, resize_to=resize_to, base_dir=dir_cache)    
            elseif griditems[id].type == SpmGridSpectrum
                create_spectrum!(griditems[id], item, base_dir=dir_cache)
            end
        end
    end
    return nothing
end


"""Paste image/spectrum parameters from `id_from` to `ids`."""
function paste_params!(griditems::Dict{String,SpmGridItem}, ids::Vector{String}, id_from::String, dir_data::String, full_resolution::Bool)::Nothing
    dir_cache = get_dir_cache(dir_data)
    type_from = griditems[id_from].type
    Threads.@threads for id in ids
        griditem = griditems[id]

        griditem.type == type_from || continue
        id != id_from || continue

        filename_original_full = joinpath(dir_data, griditem.filename_original)
        if griditem.type == SpmGridImage
            item = load_image_memcache(filename_original_full)
            properties = [:channel_name, :background_correction, :filters, :colorscheme, :channel_range_selected]
        elseif griditem.type == SpmGridSpectrum
            item = load_spectrum_memcache(filename_original_full)
            properties = [:channel_name, :channel_unit, :channel2_name, :channel2_unit, :scan_direction, :background_correction, :filters, :channel_range_selected]
        end

        changed = false
        for p in properties
            v = getfield(griditems[id_from], p)

            if p in [:channel_name, :channel2_name]  # for channels we have to make sure that these channels exist
                v in item.channel_names || continue
            end

            if v != getfield(griditem, p)
                setfield!(griditem, p, v)
                changed = true
            end
        end

        # update the image or spectrum
        if changed
            if griditem.type == SpmGridImage
                resize_to_ = full_resolution ? 0 : resize_to
                create_image!(griditem, item, resize_to=resize_to_, base_dir=dir_cache)    
            elseif griditem.type == SpmGridSpectrum
                create_spectrum!(griditem, item, base_dir=dir_cache)
            end
        end
    end
    return nothing
end


"""Creates a virtual copy of the image/spectrum with the given id."""
function create_virtual_copy!(griditems::Dict{String,SpmGridItem}, id::String, dir_data::String)::String
    dir_cache = get_dir_cache(dir_data)
    griditem = griditems[id]

    id_original = griditem.filename_original
    virtual_copies = get_virtual_copies(griditems, id_original)
    new_i = update_virtual_copies_order!(virtual_copies, id) 
    id_new, id_suffix_i = get_new_id(griditems, id_original)
    griditem_new = deepcopy(griditem)

    griditem_new.id = id_new
    griditem_new.filename_display = get_filename_display(griditem, "__virtualcopy_$(id_suffix_i)")

    # copy generated file
    f_original = joinpath(dir_cache, griditem.filename_display)
    f_new = joinpath(dir_cache, griditem_new.filename_display)
    cp(f_original, f_new, force=true)
    griditem_new.filename_display_last_modified = unix2datetime(mtime(f_new))

    griditem_new.virtual_copy = new_i
    griditems[id_new] = griditem_new

    return id_new
end


"""Loads the header data for an griditem and returns a tuple: the dictionary with all the header data, as well as some extra info"""
function get_griditem_header(griditem::SpmGridItem, dir_data::String)::Tuple{OrderedDict{String,String}, OrderedDict{String,String}}
    filename_original_full = joinpath(dir_data, griditem.filename_original)
    extra_info = OrderedDict{String,String}()
    if griditem.type == SpmGridImage
        im_spm = load_image(filename_original_full, header_only=true, output_info=0)
        return im_spm.header, extra_info
    elseif griditem.type == SpmGridSpectrum
        spectrum = load_spectrum(filename_original_full, header_only=true, index_column=true)  # no caching here
        extra_info["Channels"] = join(spectrum.channel_names, ", ")
        extra_info["Units"] = join(spectrum.channel_units, ", ")
        # we add this information to the header
        spectrum.header["Channels"] = extra_info["Channels"]
        spectrum.header["Units"] = extra_info["Units"]

        return spectrum.header, extra_info
    end
end


"""Checks if a generated image/spectrum files for `griditems` exist and are up to date."""
function griditem_cache_up_to_date(griditems::Vector{SpmGridItem}, base_dir::String="")::Bool
    for griditem in griditems
        if griditem.filename_display == ""
            return false
        end
        
        f = joinpath(base_dir, griditem.filename_display)
        lmod = mtime(f)
        if unix2datetime(lmod) != griditem.filename_display_last_modified  || lmod == 0  # mtime will give 0 for files that do not exist (so we do not need to check if file exists)
            return false
        end
    end

    return true
end


"""Sets the virtual_copy-field values in the SpmGridItems to consecutive numbers (starting with 1). Creates a position to insert a new virtual copy (after the items with id 'id').
Returns the new position."""
function update_virtual_copies_order!(virtual_copies::Array{SpmGridItem}, id::String)::Int
    sort!(virtual_copies, by=x -> x.virtual_copy)
    i_new = -1
    i = 1
    for virtual_copy in virtual_copies
        virtual_copy.virtual_copy = i
        i += 1
        if virtual_copy.id == id
            i_new = i
            i += 1
        end
    end
    if i_new == -1  # id not found, which means that the id is not a virtual copy, but the main image
        i_new = 1
        i = 2
        for virtual_copy in virtual_copies
            virtual_copy.virtual_copy = i
            i += 1
        end
    end
    return i_new
end


"""Parses files in a directory and creates the images for the default channels in a cache directory (which is a subdirectory of the data directory)"""
function parse_files(dir_data::String, w::Union{Window,Nothing}=nothing; only_new::Bool=false, output_info::Int=1)::Tuple{Dict{String, SpmGridItem},Array{String}}
    dir_cache = get_dir_cache(dir_data)
    if !isdir(dir_cache)
        mkpath(dir_cache)
    end

    # load saved data - if available
    griditems = load_all(dir_data, w)

    griditems_new = String[]
    virtual_copies_dict = Dict{String, Array{SpmGridItem}}()
    if !only_new
        # get all virtual copies that are saved
        virtual_copies_dict = get_virtual_copies_dict(griditems)
        
        # set all status to -2 (will be then re-set to 0 when the file is found in the directory)
        map(x -> x.status=-2, values(griditems))  # we do not need to use "map! (we even cant use it)
    end

    datafiles = filter!(x -> isfile(x) && (endswith(x, extension_image) || endswith(x, extension_spectrum)), readdir(dir_data, join=true))
    if w !== nothing && length(datafiles) > 1  # 1 files will have the plural-s problem in the frontend, so just skip it
        @js_ w page_start_load_params($(length(datafiles)))
    end

    num_parsed = 0
    time_start = Dates.now()
    tasks = Task[]
    for datafile in datafiles
        filename_original = basename(datafile)
        s = stat(datafile)
        created = unix2datetime(s.ctime)
        last_modified = unix2datetime(s.mtime)

        id = filename_original
        if only_new && haskey(griditems, id)
            continue
        end

        if haskey(griditems, id)
            griditem_and_virtual_copies = SpmGridItem[griditems[id]]
            if haskey(virtual_copies_dict, id)
                for virtual_copy in virtual_copies_dict[id]
                    push!(griditem_and_virtual_copies, griditems[virtual_copy.id])
                end
            end
        else
            griditem_and_virtual_copies = SpmGridItem[]
        end

        # if the filename data/lmod and the generated image/spectrum lmode didn't change, we can skip it
        if haskey(griditems, id) && griditems[id].created == created && griditems[id].last_modified == last_modified && griditem_cache_up_to_date(griditem_and_virtual_copies, dir_cache)
            griditems[id].status = 0
            if haskey(virtual_copies_dict, id)
                for virtual_copy in virtual_copies_dict[id]
                    griditems[virtual_copy.id].status = 0
                end
            end
        else
            if endswith(filename_original, extension_image)
                ts = parse_image!(griditems, virtual_copies_dict, griditems_new, only_new,
                    dir_cache, datafile, id, filename_original, created, last_modified)
                append!(tasks, ts)
            elseif endswith(filename_original, extension_spectrum)
                ts = parse_spectrum!(griditems, virtual_copies_dict, griditems_new, only_new,
                    dir_cache, datafile, id, filename_original, created, last_modified)
                append!(tasks, ts)
            end
        end

        num_parsed += 1
        # indicate progress
        if num_parsed % show_load_progress_every == 0
            if w !== nothing
                prog1 = num_parsed / length(datafiles)
                prog100 = ceil(prog1 * 100)
                @js_ w page_start_load_progress($prog100)
                Blink.progress(w, prog1)
            end
        end

        if cancel_sent
            break
        end
    end
    wait.(tasks)

    elapsed_time = Dates.now() - time_start
    if output_info > 0
        msg = "Parsed $(num_parsed) files and created $(length(griditems)) items in $elapsed_time."
        log(msg, w)
    end
    return griditems, griditems_new
end


"""shows error"""
function error(e::Exception, w::Window, show::Bool=true)
    msg = sprint(showerror, e)
    msg_full = sprint(showerror, e, catch_backtrace())
    println(msg)
    println(msg_full)
    
    @js_ w show_error($msg)
    if show
        @js_ w console.log($msg_full)
    end
    return nothing
end


"""logs message to console and stdout"""
function log(msg::AbstractString, w::Union{Window,Nothing}; new_line::Bool=true)
    if w !== nothing
        @js_ w console.log($msg)
    end
    if new_line
        println(msg)
    else
        print(msg)
    end

    return nothing
end


"""loads html from a file into a div.htmlimport - this is then loaded into the document body by the js function `load_page`"""
function loadhtml!(w::Window,  fname::String)
    s = open(fname) do file
        read(file, String)
    end

    expr = JSExpr.@js begin
        @var el = document.createElement("div")
        el.style.display = "none"
        el.className = "htmlimport"
        el.innerHTML = $s
        document.body.appendChild(el)
    end

    Blink.js(w, expr, callback=true)
end


"""Loads images in specific directory"""
function load_directory(dir_data::String, w::Window; output_info::Int=1)::Nothing
    # parse images etc
    global cancel_sent = false  # user might send cancel during the next step

    # remove old cache
    global memcache_images = ListNodeCache{SpmImage}(memcache_mb_images)
    global memcache_spectra = ListNodeCache{SpmSpectrum}(memcache_mb_spectra)

    griditems, _ = parse_files(dir_data, w, output_info=output_info)
    bottomleft, topright = get_scan_range(griditems)
    if cancel_sent
        msg = "Cancelled loading $dir_data"
        @js_ w page_start_load_error($msg)
        global cancel_sent = false
        return nothing
    elseif length(griditems) == 0
        msg = "There are no SPM files in $dir_data"
        @js_ w page_start_load_error($msg)
        return nothing
    end
    filenames_colorbar = save_colorbars(colorscheme_list, dir_data)

    # call js functions to setup everything
    dir_data_js = add_trailing_slash(dir_data)
    dir_cache = get_dir_cache(dir_data)
    dir_cache_js = add_trailing_slash(dir_cache)
    dir_colorbars_js = add_trailing_slash(joinpath(dir_cache, dir_colorbars))
    @js_ w set_params_project($dir_data_js, $dir_cache_js, $dir_colorbars_js, $filenames_colorbar)
    
    # only send the images with status >=0 (deleted ones are not sent, but still saved)
    griditems_values = NaturalSort.sort!(filter(im->im.status >= 0, collect(values(griditems))), by=im -> (im.recorded, im.filename_original, im.virtual_copy))  # NaturalSort will sort number suffixes better
    json_compressed = transcode(GzipCompressor, JSON.json(griditems_values))
    @js_ w load_images($json_compressed, $bottomleft, $topright, true)

    set_event_handlers(w, dir_data, griditems)

    save_config(dir_data)  # set and save new last dirs
    @js_ w set_last_directories($last_directories)

    Blink.progress(w, -1)

    return nothing
end


"""Start the main GUI and loads images from dir_data (if specified)"""
function tycoon(dir_data::String=""; return_window::Bool=false, keep_alive::Bool=true)::Union{Window,Nothing}
    global Precompiling = false
    global exit_tycoon = false
    
    file_logo = path_asset("media/logo_diamond.png")
    w = Window(Dict(
        "webPreferences" => Dict(
            "webSecurity" => false,  # to load local files
            "nodeIntegration" => true,  # for require("..") within the renderer process
            "contextIsolation" => false  # for require("..") within the renderer process
        ),
        "title" => "SpmImage Tycoon",
        "icon" => file_logo,
    ))
    Blink.AtomShell.@dot w setMenuBarVisibility(false)
    Blink.AtomShell.@dot w setIcon($file_logo)
    Blink.AtomShell.@dot w maximize()

    load_config()
    if length(colorscheme_list) != 2*length(colorscheme_list_pre)  # only re-generate if necessary
        generate_colorscheme_list!(colorscheme_list, colorscheme_list_pre)  # so we have 1024 steps in each colorscheme - also automatically create the inverted colorschemes
    end

    # load main html file
    file_GUI = path_asset("GUI.html")
    # load!(w, file_GUI)
    loadhtml!(w, file_GUI)
    
    # load all .css and .js asset files
    dir_asset = path_asset("");
    dir_asset_external = path_asset("external/");
    asset_files = vcat(readdir(dir_asset, join=true), readdir(dir_asset_external, join=true))
    filter!(
        x -> isfile(x) && (endswith(x, ".css") || endswith(x, ".js")),
        asset_files
    )
    for asset_file in asset_files
        load!(w, asset_file)
    end
    
    # get versions
    versions = Dict{String,String}(
        "SpmImageTycoon" => string(VERSION),
        "SpmImages" => string(SpmImages.VERSION),
        "SpmSpectroscopy" => string(SpmSpectroscopy.VERSION),
    )
            
    @js w set_params($dir_asset, $auto_save_minutes, $overview_max_images)
    @js w set_last_directories($last_directories)
    @js w load_page($versions)
    @js w show_start()

    set_event_handlers_basic(w)

    if dir_data != ""
        load_directory(abspath(dir_data), w)
    end
    
    # bring window to front
    Blink.AtomShell.@dot w show()

    if keep_alive
        while active(w) && !exit_tycoon
            yield()
            sleep(0.1)
        end
    end
    if return_window
        return w
    else
        return nothing
    end
end


@precompile_setup begin
    global Precompiling = true
    fname_spec = joinpath(@__DIR__ , "../test/data/Z-Spectroscopy420.dat")
    fname_img = joinpath(@__DIR__ , "../test/data/Image_002.sxm")
    DIR_db_old = joinpath(@__DIR__ , "../test/data/old_db/")
    DIR_data = joinpath(@__DIR__ , "../test/data/")
    DIR_cache = get_dir_cache(DIR_data) 
    FNAME_odp = joinpath(@__DIR__ , "../test/test_presentation.odp")
    file_GUI = path_asset("GUI.html")
    dir_asset = path_asset("");
    dir_asset_external = path_asset("external/");
    asset_files = vcat(readdir(dir_asset, join=true), readdir(dir_asset_external, join=true))
    versions = Dict{String,String}(
        "SpmImageTycoon" => string(VERSION),
        "SpmImages" => string(SpmImages.VERSION),
        "SpmSpectroscopy" => string(SpmSpectroscopy.VERSION),
    )
    include(joinpath(@__DIR__ , "../test/functions.jl"))


    @precompile_all_calls begin
        return 0
        spec = load_spectrum(fname_spec)
        ima = load_image(fname_img, output_info=0)
        df = get_channel(ima, "Frequency shift")
        SpmImages.correct_background(df.data, line_average)
        SpmImages.correct_background(df.data, line_linear_fit)
        SpmImages.correct_background(df.data, vline_average)
        SpmImages.correct_background(df.data, vline_linear_fit)
        SpmImages.correct_background(df.data, plane_linear_fit)
        d = SpmImages.correct_background(df.data, SpmImages.subtract_minimum)
        normalize01!(d)
        clamp01nan!(d)

        SpmImageTycoon.load_all(DIR_db_old, nothing)

        # we need to make it global for the test-functions below (send_click)
        w = Window(
            Dict(
                "webPreferences" => Dict(
                    "webSecurity" => false,
                    "nodeIntegration" => true,
                    "contextIsolation" => false
                ),
                :transparent => true,
                :frame => false,
                :titleBarStyle => "hidden",
                :show => false
            )
        )
        # Blink.AtomShell.@dot w hide()
        # Blink.AtomShell.@dot w setIgnoreMouseEvents(true)

        load_config()
        if length(colorscheme_list) != 2*length(colorscheme_list_pre)  # only re-generate if necessary
            generate_colorscheme_list!(colorscheme_list, colorscheme_list_pre)  # so we have 1024 steps in each colorscheme - also automatically create the inverted colorschemes
        end
        loadhtml!(w, file_GUI)
        filter!(
            x -> isfile(x) && (endswith(x, ".css") || endswith(x, ".js")),
            asset_files
        )
        for asset_file in asset_files
            load!(w, asset_file)
        end
        @js w set_params($dir_asset, 0, 100)

        @js w load_page($versions)
        @js w show_start()
   
        set_event_handlers_basic(w)

        delete_files(;dir_cache=DIR_cache, fname_odp=FNAME_odp)
        load_directory(abspath(DIR_data), w, output_info=0)

        selected = ["Image_004.sxm"]
        sel = selector(selected)
        send_hover_mouse(sel, window=w)

        @js w get_image_info("Image_004.sxm")

        selected = ["Image_002.sxm", "Image_004.sxm"]
        sel = selector(selected)
        send_click(sel, window=w)
        send_key(["b", "b", "b", "b", "b", "c", "c", "i", "p"], window=w)
    
        items = get_items(window=w)
    end
end


"""Entry point for sysimage/binary created by PackageCompiler.jl"""
function julia_main()::Cint
    if "--test" in ARGS
        cd(joinpath(@__DIR__ , "../test/"))
        include(joinpath(@__DIR__ , "../test/runtests.jl"))
    else
        tycoon()
    end
    return 0
end

end