__precompile__()

module SpmImageTycoon

using Blink
using CodecZlib
using ColorSchemes
using DataStructures
using Dates
using Images
using ImageIO
using JLD2
using JSON
using NaturalSort
using SpmImages
using SpmSpectroscopy
using StatsBase

export SpmGridItem, tycoon


@enum SpmGridItemType SpmGridImage SpmGridSpectrum

# entries for SPM images and SPM spectra
mutable struct SpmGridItem_v128
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
    center::Vector{Float64}                    # center of scan frame or position of spectrum (in scansize_units) 
    angle::Float64                             # scan angle (in degrees), not used for spectra
    scan_direction::Bool                       # scan direction (true = up, false = down), not used for spectra

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

    SpmGridItem_v128(; id="", type=SpmGridImage, filename_original="", created=DateTime(-1), last_modified=DateTime(-1), recorded=DateTime(-1),
        filename_display="", filename_display_last_modified=DateTime(-1),  # for non-excisting files mtime will give 0, so we set it to -1 here
        channel_name="", channel_unit="", channel2_name="", channel2_unit="",
        scansize=[], scansize_unit="", center=[], angle=0, scan_direction=false,
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
SpmGridItem = SpmGridItem_v128
SpmImageGridItem = SpmGridItem_v128  # legacy, for old databases


include("config.jl")
include("helper_functions.jl")
include("image_functions.jl")
include("spectrum_functions.jl")
include("export.jl")


exit_tycoon = false  # if set to true, then keep-alive loop will end
cancel_sent = false  # user can cancel load-directory operation



"""sets keywords"""
function set_keywords!(ids::Vector{String}, dir_data::String, images_parsed::Dict{String,SpmGridItem}, mode::String, keywords::Vector{String})
    for id in ids
        if mode == "add"
            for keyword in keywords
                if keyword ∉ images_parsed[id].keywords
                    push!(images_parsed[id].keywords, keyword)
                end
            end
        elseif mode == "remove"
            filter!(k -> k ∉ keywords, images_parsed[id].keywords)
        else  # set
            images_parsed[id].keywords = keywords
        end
        sort!(images_parsed[id].keywords)
    end
    return nothing
end


"""returns a subset of the dictionary parsed_images. this can then be passed to the js"""
function get_subset(images_parsed::Dict{String, SpmGridItem}, ids::Vector{String})::OrderedDict{String, SpmGridItem}
    images_parsed_sub = OrderedDict{String, SpmGridItem}()
    map(ids) do id
        images_parsed_sub[id] = images_parsed[id]
    end
    return images_parsed_sub
end


"""gets a dictionary "original_id" => (array of virtual copies) with all virtual copies in images_parsed"""
function get_virtual_copies_dict(images_parsed::Dict{String, SpmGridItem})::Dict{String,Array{SpmGridItem}}
    virtual_copies = filter(x -> last(x).virtual_copy > 0, images_parsed)
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
function get_virtual_copies(images_parsed::Dict{String, SpmGridItem}, id::String)::Array{SpmGridItem}
    virtual_copies = filter(x -> last(x).filename_original==id && last(x).virtual_copy > 0, images_parsed)
    return collect(values(virtual_copies))
end


"""Generates a new unique id that is not yet present in images_parsed by appending numbers to the given id"""
function get_new_id(images_parsed::Dict{String, SpmGridItem},id_original::String)::String
    id = id_original
    i = 1
    while true
        id = "$(id_original)_$i"
        if !haskey(images_parsed, id)
            break
        end
        i += 1
    end
    return id
end


"""Returns the scan range of all images. Returns bottom left and top right corner coordinates."""
function get_scan_range(images_parsed::Dict{String, SpmGridItem})::Tuple{Vector{Float64},Vector{Float64}}
    c = first(values(images_parsed)).center
    min_max_corners_x = [c[1], c[1]]
    min_max_corners_y = [c[2], c[2]]
    for img in values(images_parsed)
        if img.virtual_copy > 0 || img.status < 0
            continue
        end

        if img.type == SpmGridSpectrum
            return (img.center, img.center)
        end

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
    bottomleft = [min_max_corners_x[1], min_max_corners_y[1]]
    topright = [min_max_corners_x[2], min_max_corners_y[2]]

    return bottomleft, topright
end


"""Loads the header data for an griditem and returns a tuple: the dictionary with all the header data, as well as some extra info"""
function get_griditem_header(griditem::SpmGridItem, dir_data::String)::Tuple{OrderedDict{String,String}, OrderedDict{String,String}}
    filename_original_full = joinpath(dir_data, griditem.filename_original)
    extra_info = OrderedDict{String,String}()
    if griditem.type == SpmGridImage
        im_spm = load_image(filename_original_full, header_only=true, output_info=0)
        return im_spm.header, extra_info
    elseif griditem.type == SpmGridSpectrum
        spectrum = load_spectrum(filename_original_full, header_only=true, index_column=true)
        extra_info["Channels"] = join(spectrum.channel_names, ", ")
        extra_info["Units"] = join(spectrum.channel_units, ", ")
        # we add this information to the header
        spectrum.header["Channels"] = extra_info["Channels"]
        spectrum.header["Units"] = extra_info["Units"]

        return spectrum.header, extra_info
    end
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

    # load saved data - if available
    images_parsed = load_all(dir_data, w)

    images_parsed_new = String[]
    virtual_copies_dict = Dict{String, Array{SpmGridItem}}()
    if !only_new
        # get all virtual copies that are saved
        virtual_copies_dict = get_virtual_copies_dict(images_parsed)
        
        # set all status to -2 (will be then re-set to 0 when the file is found in the directory)
        map(x -> x.status=-2, values(images_parsed))  # we do not need to use "map! (we even cant use it)
    end

    datafiles = filter!(x -> isfile(x) && (endswith(x, extension_image) || endswith(x, extension_spectrum)), readdir(dir_data, join=true))
    if w !== nothing && length(datafiles) > 1  # 1 files will have the plural-s problem in the frontend, so just skip it
        @js_ w page_start_load_params($(length(datafiles)))
    end

    num_parsed = 0
    time_start = Dates.now()
    @sync for datafile in datafiles
        filename_original = basename(datafile)
        s = stat(datafile)
        created = unix2datetime(s.ctime)
        last_modified = unix2datetime(s.mtime)

        id = filename_original
        if only_new && haskey(images_parsed, id)
            continue
        end

        if endswith(filename_original, extension_image)
            parse_image!(images_parsed, virtual_copies_dict, images_parsed_new, only_new,
                dir_cache, datafile, id, filename_original, created, last_modified)
        elseif endswith(filename_original, extension_spectrum)
            parse_spectrum!(images_parsed, virtual_copies_dict, images_parsed_new, only_new,
                dir_cache, datafile, id, filename_original, created, last_modified)
        end

        num_parsed += 1
        # indicate progress
        if num_parsed % show_load_progress_every == 0
            if w !== nothing
                progress = ceil(num_parsed / length(datafiles) * 100)
                @js_ w page_start_load_progress($progress)
            end
        end

        if cancel_sent
            break
        end
    end

    elapsed_time = Dates.now() - time_start
    if output_info > 0
        msg = "Parsed $(num_parsed) files and created $(length(images_parsed)) items in $elapsed_time."
        log(msg, w)
    end
    return images_parsed, images_parsed_new
end


"""load data from saved file"""
function load_all(dir_data::String, w::Union{Window,Nothing})::Dict{String, SpmGridItem}
    images_parsed = Dict{String, SpmGridItem}()
    
    f = joinpath(get_dir_cache(dir_data), filename_db)
    if isfile(f)
        JLD2.@load f images_parsed_save

        if length(images_parsed_save) == 0
            return images_parsed
        end

        first_value = first(values(images_parsed_save))
        t_save = typeof(first_value)
        if t_save <: Pair # JLD2 apparently reconstructs an array of pairs{id, SpmGridItem}
            t_save = typeof(first_value[2])
        end

        if t_save != SpmGridItem  # there was a change in the struct specification, lets try to copy field by field
            log("Old database detected. Converting... ", w, new_line=false)

            fieldnames_save = fieldnames(t_save)
            fieldnames_common = filter(x -> x in fieldnames_save, fieldnames(SpmGridItem))

            for pair in images_parsed_save  # JLD2 apparently reconstructs an array of pairs{id, SpmGridItem}
                id = pair[1]
                griditem = pair[2]
                images_parsed[id] = SpmGridItem()
                for f in fieldnames_common
                    setfield!(images_parsed[id], f, getfield(griditem, f))
                end
            end

            log("ok.", w)
        else
            images_parsed = images_parsed_save
        end
    end

    return images_parsed
end


"""saves the images_parsed dictionary to file"""
function save_all(dir_data::String, images_parsed::Dict{String, SpmGridItem})
    f = joinpath(get_dir_cache(dir_data), filename_db)
    JLD2.@save f images_parsed_save=images_parsed
    return nothing
end


"""sets the julia handlers that are triggered by javascript events"""
function set_event_handlers(w::Window, dir_data::String, images_parsed::Dict{String,SpmGridItem})
    # change channel
    l = ReentrantLock()  # not sure if it is necessary to do it here, but it shoul be safer this way
    handle(w, "grid_item") do args  # cycle through scan channels
        # @show args
        what = args[1]
        ids = string.(args[2])  # for some reason its type is "Any" and not String
        if what == "get_info"
            id = ids[1]
            histogram = args[3]
            # get header data
            try
                image_header, extra_info = get_griditem_header(images_parsed[id], dir_data)
                k = replace.(collect(keys(image_header)), ">" => "><wbr>")[3:end]  # replace for for word wrap in tables
                v = replace.(collect(values(image_header)), "\n" => "<br />")[3:end]  # the first two rows are not useful to display, so cut them off
                v = utf8ify.(v)
                image_header_json = JSON.json(vcat(reshape(k, 1, :), reshape(v, 1, :)))
                json_compressed = transcode(GzipCompressor, image_header_json)
                @js_ w show_info($id, $json_compressed, $extra_info);
                if histogram
                    width, counts = get_histogram(images_parsed[id], dir_data)
                    @js_ w show_histogram($id, $width, $counts)
                end
            catch e
                error(e, w)
            end
        elseif what[1:5] == "next_"
            lock(l)
            jump = args[3]
            full_resolution = args[4]
            try
                switch_channel_direction_background!(ids, dir_data, images_parsed, what[6:end], jump, full_resolution)
                images_parsed_sub = get_subset(images_parsed, ids)
                json_compressed = transcode(GzipCompressor, JSON.json(images_parsed_sub))
                @js_ w update_images($json_compressed);
            catch e
                error(e, w)
            finally
                unlock(l)
            end
        elseif what[1:4] == "set_"
            if what[5:end] == "rating"
                lock(l)
                rating = args[3]
                try
                    for id in ids
                        images_parsed[id].rating = rating
                    end
                    images_parsed_sub = get_subset(images_parsed, ids)
                    json_compressed = transcode(GzipCompressor, JSON.json(images_parsed_sub))
                    @js_ w update_images($json_compressed);
                catch e
                    error(e, w)
                finally
                    unlock(l)
                end
            elseif what[5:end] == "keywords"
                lock(l)
                mode = args[3]
                keywords = string.(args[4])
                if length(keywords) == 0  # for whatever reason an empty array does not get converted to a stirng type empty array
                    keywords = String[]
                end
                try
                    set_keywords!(ids, dir_data, images_parsed, mode, keywords)
                    images_parsed_sub = get_subset(images_parsed, ids)
                    json_compressed = transcode(GzipCompressor, JSON.json(images_parsed_sub))
                    @js_ w update_images($json_compressed);
                catch e
                    error(e, w)
                finally
                    unlock(l)
                end
            elseif what[5:end] == "range_selected"
                lock(l)
                range_selected = float.(args[3])
                full_resolution = args[4]
                try
                    set_range_selected!(ids, dir_data, images_parsed, range_selected, full_resolution)
                    images_parsed_sub = get_subset(images_parsed, ids)
                    json_compressed = transcode(GzipCompressor, JSON.json(images_parsed_sub))
                    @js_ w update_images($json_compressed);
                catch e
                    error(e, w, false)  # do not show modal-dialog for user if anything goes wrong
                finally
                    unlock(l)
                end
            end
        elseif what == "get_line_profile"
            lock(l)  # might not be necessary here, as it is just a read operation - but images_parsed might change, so let's keep it
            id = ids[1]
            try
                start_point = float.(args[3])
                end_point = float.(args[4])
                width = float(args[5])
                # start_point_value and end_point_value is just the point (width does not affect it)
                coords, distances, values, start_point_value, end_point_value = get_line_profile(id, dir_data, images_parsed, start_point, end_point, width)
                @js_ w show_line_profile($id, $distances, $values, $start_point_value, $end_point_value)
            catch e
                error(e, w, false)  # do not show modal-dialog for user if anything goes wrong
            finally
                unlock(l)
            end
        elseif what == "virtual_copy"
            lock(l)
            mode = args[3]
            try
                if mode =="create"
                    updated_virtual_copy_is = Dict{String, Int}()  # save updated virtual copy values (so that we keep js and julia in sync - might be important for js-sorting)
                    ids_new = Array{String}(undef, 0)
                    for id in ids
                        id_original = images_parsed[id].filename_original
                        virtual_copies = get_virtual_copies(images_parsed, id_original)
                        new_i = update_virtual_copies_order!(virtual_copies, id) 
                        id_new = get_new_id(images_parsed, id_original)
                        virtual_copy_new = deepcopy(images_parsed[id])
                        virtual_copy_new.id = id_new
                        virtual_copy_new.virtual_copy = new_i
                        images_parsed[id_new] = virtual_copy_new

                        push!(ids_new, id_new)
                        for virtual_copy in virtual_copies
                            updated_virtual_copy_is[virtual_copy.id] = virtual_copy.virtual_copy
                        end
                    end

                    images_parsed_sub = get_subset(images_parsed, ids_new)
                    @js_ w insert_images($images_parsed_sub, $ids)  # insert images after positions of ids
                elseif mode =="delete"
                    for id in ids
                        if haskey(images_parsed, id) && images_parsed[id].virtual_copy > 0
                            delete!(images_parsed, id)
                        end
                    end
                    @js_ w delete_images($ids)
                end
            catch e
                error(e, w)
            finally
                unlock(l)
            end
        elseif what == "export_odp"
            lock(l)
            filename_export = args[3]
            try
                export_odp(ids, dir_data, images_parsed, filename_export)
                @js_ w exported()
            catch e
                if (:msg in fieldnames(typeof(e)))  # this is often a file-busy error
                    msg = string(e.msg)
                    @js_ w show_error($msg)
                else
                    error(e, w)
                end
            finally
                unlock(l)
            end
        end
    end

    handle(w, "re_parse_images") do args
        parse_all = args[1]
        lock(l)
        try
            global cancel_sent = false  # user might send cancel during the next steps
            save_all(dir_data, images_parsed)
            images_parsed, images_parsed_new = parse_files(dir_data, only_new=!parse_all)
            bottomleft, topright = get_scan_range(images_parsed)
            if cancel_sent
                @js_ w console.log()
                global cancel_sent = false
            else
                # only send the images with status >=0 (deleted ones are not sent, but still saved)
                images_parsed_values = NaturalSort.sort!(collect(filter(im->im.status >= 0, collect(values(images_parsed)))), by=im -> (im.recorded, im.filename_original, im.virtual_copy))  # NaturalSort will sort number suffixes better
                if parse_all
                    json_compressed = transcode(GzipCompressor, JSON.json(images_parsed_values))
                    @js_ w load_images($json_compressed, $bottomleft, $topright, $parse_all, true)
                else
                    ids_after = String[]
                    images_parsed_sub = OrderedDict{String, SpmGridItem}()
                    prev_id = ""
                    global images_parsed_values_test = copy(images_parsed_values)
                    for im in images_parsed_values
                        if im.id in images_parsed_new
                            images_parsed_sub[im.id] = im
                            push!(ids_after, prev_id)
                            @show im.id, prev_id
                        end
                        prev_id = im.id
                    end
                    @show images_parsed_sub, ids_after
                    @js_ w insert_images($images_parsed_sub, $ids_after)  # insert images after positions of ids
                end
            end
        catch e
            error(e, w)
        finally
            unlock(l)
        end
    end

    handle(w, "save_all") do args
        lock(l)
        if args[1] == true
            global exit_tycoon = true
        end
        try
            if dir_data != ""
                save_all(dir_data, images_parsed)
            end
            @js_ w saved_all()
        catch e
            error(e, w)
        finally
            unlock(l)
        end
    end

    handle(w, "exit") do args
        global exit_tycoon = true
    end

    return nothing
end


"""sets basic event handlers"""
function set_event_handlers_basic(w::Window)
    l = ReentrantLock()  # not sure if it is necessary to do it here, but it shoul be safer this way

    handle(w, "load_directory") do arg
        lock(l)
        try
            dir = abspath(arg)
            if !isdir(dir)
                msg = "Can not open directory $dir"
                @js_ w page_start_load_error($msg)
            else
                load_directory(dir, w)
            end
        catch e
            error(e, w)
        finally
            unlock(l)
        end
    end

    handle(w, "cancel") do args
        global cancel_sent = true
    end

    handle(w, "debug") do args
        println("debug: " * string(args))
    end

    return nothing
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


"""Loads images in specific directory"""
function load_directory(dir_data::String, w::Window)
    # parse images etc
    global cancel_sent = false  # user might send cancel during the next step
    images_parsed, _ = parse_files(dir_data, w)
    bottomleft, topright = get_scan_range(images_parsed)
    if cancel_sent
        msg = "Cancelled loading $dir_data"
        @js_ w page_start_load_error($msg)
        global cancel_sent = false
        return nothing
    elseif length(images_parsed) == 0
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
    images_parsed_values = NaturalSort.sort!(filter(im->im.status >= 0, collect(values(images_parsed))), by=im -> (im.recorded, im.filename_original, im.virtual_copy))  # NaturalSort will sort number suffixes better
    json_compressed = transcode(GzipCompressor, JSON.json(images_parsed_values))
    @js_ w load_images($json_compressed, $bottomleft, $topright, true)

    set_event_handlers(w, dir_data, images_parsed)

    save_config(dir_data)  # set and save new last dirs
    @js_ w set_last_directories($last_directories)

    return nothing
end


"""Start the main GUI and loads images from dir_data (if specified)"""
function tycoon(dir_data::String=""; return_window::Bool=false, keep_alive::Bool=true)::Union{Window,Nothing}
    file_logo = path_asset("logo_diamond.png")
    w = Window(Dict(
        "webPreferences" => Dict("webSecurity" => false),  # to load local files
        "title" => "SpmImage Tycoon",
        "icon" => file_logo,
    ))
    @js w require("electron").remote.getCurrentWindow().setMenuBarVisibility(false)
    @js w require("electron").remote.getCurrentWindow().setIcon($file_logo)
    @js w require("electron").remote.getCurrentWindow().maximize()

    load_config()
    if length(colorscheme_list) != 2*length(colorscheme_list_pre)  # only re-generate if necessary
        colorscheme_list_to_256!(colorscheme_list, colorscheme_list_pre)  # so we have 256 steps in each colorscheme - also automatically create the inverted colorschemes
    end

    # load main html file
    file_GUI = path_asset("GUI.html")
    load!(w, file_GUI)

    # load all .css and .js asset files
    dir_asset = path_asset("");
    asset_files = filter!(
        x -> isfile(x) && (endswith(x, ".css") || endswith(x, ".js")),
        readdir(dir_asset, join=true)
    )
    for asset_file in asset_files
        load!(w, asset_file)
    end

    @js_ w set_params($dir_asset, $auto_save_minutes, $overview_max_images)
    @js_ w set_last_directories($last_directories)
    @js_ w load_page()
    @js_ w show_start()

    set_event_handlers_basic(w)

    if dir_data != ""
        load_directory(abspath(dir_data), w)
    end
    
    # bring window to front
    @js w require("electron").remote.getCurrentWindow().show()

    if keep_alive
        while !exit_tycoon
            yield()
            sleep(0.05)
        end
    end
    if return_window
        return w
    else
        return nothing
    end
end


"""Entry point for sysimage/binary created by PackageCompiler.jl"""
function julia_main()::Cint
    tycoon()
    return 0
end

end