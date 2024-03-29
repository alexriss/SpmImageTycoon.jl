module SpmImageTycoon

using Blink
using CodecZlib
using ColorSchemes
using DataFrames
using DataStructures: OrderedDict
using Dates
using DSP
using FFTW
using Images
using ImageFiltering
using ImageIO
using JLD2
using JSExpr
using JSON
using NaturalSort
using SkipNan
using PrecompileTools
using SpmImages
using SpmSpectroscopy
using StatsBase
using TOML

export SpmGridItem, tycoon

const VERSION = VersionNumber(TOML.parsefile(joinpath(@__DIR__, "../Project.toml"))["version"]) 


@enum SpmGridItemType SpmGridImage SpmGridSpectrum

# entries for SPM images and SPM spectra
mutable struct SpmGridItem_v130
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
    edits::Vector{String}                      # array of edits used
    keywords::Vector{String}                   # keywords
    rating::Int64                              # rating (0 to 5 stars)
    status::Int64                              # status, i.e. 0: normal, 10: writen to temp-cache (due to write permissions), -2: being parsed/generated
    virtual_copy::Int64                        # specifies whether this is a virtual copy, i.e. 0: original image, >=1 virtual copies

    SpmGridItem_v130(; id="", type=SpmGridImage, filename_original="", created=DateTime(-1), last_modified=DateTime(-1), recorded=DateTime(-1),
        filename_display="", filename_display_last_modified=DateTime(-1),  # for non-excisting files mtime will give 0, so we set it to -1 here
        channel_name="", channel_unit="", channel2_name="", channel2_unit="",
        scansize=[], scansize_unit="nm", center=[], angle=0, scan_direction=0,
        bias=0, z_feedback=false, z_feedback_setpoint=0, z_feedback_setpoint_unit="", z=0.0, points=0,
        comment="", background_correction="none", colorscheme="gray",
        channel_range=[], channel_range_selected=[], edits=[], keywords=[], rating=0, status=0, virtual_copy=0) =
    new(id, type, filename_original, created, last_modified, recorded,
        filename_display, filename_display_last_modified,
        channel_name, channel_unit, channel2_name, channel2_unit,
        scansize, scansize_unit, center, angle, scan_direction,
        bias, z_feedback, z_feedback_setpoint, z_feedback_setpoint_unit, z, points,
        comment, background_correction, colorscheme,
        channel_range, channel_range_selected, edits, keywords, rating, status, virtual_copy)
end
SpmGridItem = SpmGridItem_v130


include("config.jl")
include("cache.jl")
include("helper_functions.jl")
include("image_functions.jl")
include("spectrum_functions.jl")
include("gxsm_functions.jl")
include("export.jl")
include("event_handlers.jl")
include("db_functions.jl")
include("editing.jl")


exit_tycoon = false  # if set to true, then keep-alive loop will end
cancel_sent = false  # user can cancel load-directory operation
griditems_last_saved = 0.  # time of last save of griditems
griditems_last_changed = 0.  # time of last (potential) change of griditems - we do not keep track of actual changes, but only if certain events happen
griditems_lock = ReentrantLock()

channel_names_files = Dict{String,Dict{String,String}}()  # list of channel names and the respective files (used for GXSM, where each channel has one file)

Precompiling = false

"""sorts channel names"""
function sort_channel_names(channel_names::Vector{String})::Vector{String}
    if sort_channel_list  # global config variable
        return NaturalSort.sort(channel_names, by = x -> lowercase(x))
    else
        return channel_names
    end
end


"""sorts channel names and units"""
function sort_channel_names_units(channel_names::Vector{String}, channel_units::Vector{String})::Tuple{Vector{String}, Vector{String}}
    if sort_channel_list  # global config variable
        perm = NaturalSort.sortperm(channel_names, by = x -> lowercase(x))
        return channel_names[perm], channel_units[perm]
    else
        return channel_names, channel_units
    end
end


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
function get_virtual_copies_dict(griditems::Dict{String, SpmGridItem})::Dict{String,Vector{SpmGridItem}}
    virtual_copies = filter(x -> last(x).virtual_copy > 0, griditems)
    virtual_copies_dict = Dict{String, Vector{SpmGridItem}}()  # create a dict for quick lookup
    for virtual_copy in values(virtual_copies)
        id_original = virtual_copy.filename_original
        if !haskey(virtual_copies_dict, id_original)
            virtual_copies_dict[id_original] = Vector{SpmGridItem}(undef, 0);
        end
        push!(virtual_copies_dict[id_original], virtual_copy)
    end

    return virtual_copies_dict
end


"""gets the virtual copies that have been created for id. Returns an array of SpmGridItem"""
function get_virtual_copies(griditems::Dict{String, SpmGridItem}, id::String)::Vector{SpmGridItem}
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
    if is_gxsm_image(griditem.filename_original)
        filename_display = splitext(base_filename(griditem.filename_original))[1] * suffix
    else
        filename_display = splitext(base_filename(griditem.filename_original))[1] * suffix
    end

    if griditem.type == SpmGridSpectrum
        filename_display *= ".svg"
    else
        filename_display *= ".png"
    end
    
    return filename_display
end


"""Gets channels and channels2 for the given ids"""
function get_channels(ids::Vector{String}, griditems::Dict{String, SpmGridItem}, channel_names_list::Dict{String,Vector{String}})::Tuple{OrderedDict{String,Dict},OrderedDict{String,Dict}}
    channels = OrderedDict{String,Dict}()
    channels2 = OrderedDict{String,Dict}()

    for id in ids
        !haskey(griditems, id) && continue
        filename_base = base_filename(griditems[id].filename_original)
        !haskey(channel_names_list, filename_base) && continue  # should never happen, though
        for ch in channel_names_list[filename_base]
            (griditems[id].type == SpmGridSpectrum) && endswith(ch, " [bwd]") && continue

            if !haskey(channels, ch)
                channels[ch] = Dict(
                    "val" => ch,
                    "for" => [griditems[id].type]
                )
            else
                push!(channels[ch]["for"], griditems[id].type)
            end
            
            if griditems[id].type === SpmGridSpectrum
                if !haskey(channels2, ch)
                    channels2[ch] = Dict(
                        "val" => ch,
                        "for" => [griditems[id].type]
                    )
                end
            end
        end
    end
    # always sort here
    NaturalSort.sort!(channels, by = x -> lowercase(x))
    NaturalSort.sort!(channels2, by = x -> lowercase(x))
    return channels, channels2
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


"""Changes the griditem fieldnames. Cycles/toggles the respective property. Returns if caching is safe."""
function pre_change_griditem!(griditem::SpmGridItem, item::Union{SpmImage,SpmSpectrum}, what::String, jump::Int=1)::Tuple{Bool,Bool}
    # multiple dispatch for update functions
    if what == "channel"
        next_channel_name!(griditem, item, jump)
    elseif what == "channel2"
        next_channel2_name!(griditem, item, jump)
    elseif what == "direction"
        next_direction!(griditem, item)
    elseif what == "background_correction"
        next_background_correction!(griditem, item, jump)
    elseif what == "colorscheme"
        next_colorscheme!(griditem, item, jump)
    elseif what == "inverted"
        next_invert!(griditem, item)
    else
        println("Unknown property to change: ", what)  # this should never happen, though
        return false, true
    end
    return true, true
end


"""Changes the griditem fieldnames. Changes multiple properties to specific values. Returns if caching is safe."""
function pre_change_griditem!(griditem::SpmGridItem, item::Union{SpmImage,SpmSpectrum}, state::Dict, jump::Int)::Tuple{Bool,Bool}
    # set new properties for griditem - we also do some checks
    cache_safe = true
    changed = false
    for (k,v) in state
        if k =="channel_name"
            v_ = v
            if griditem.type == SpmGridImage
                if is_image_channel_name_fwd(griditem.channel_name)
                    v = image_channel_name_fwd(v)
                else
                    v = image_channel_name_bwd(v)
                end
            end
            if (v_ in item.channel_names) && (v != griditem.channel_name)
                griditem.channel_name = v
                changed = true
            end
        elseif k == "channel2_name" && griditem.type == SpmGridSpectrum
            if (v in item.channel_names) && (v != griditem.channel2_name)
                griditem.channel2_name = v
                changed = true
            end
        elseif k == "scan_direction" && griditem.type == SpmGridSpectrum
            v = parse(Int, v)
            if v in (0, 1, 2) && v != griditem.scan_direction
                griditem.scan_direction = v
                changed = true
            end
        elseif k == "scan_direction" && griditem.type == SpmGridImage
            v = parse(Int, v)
            c = griditem.channel_name
            if v == 0
                c = image_channel_name_fwd(c)
            elseif v == 1
                c = image_channel_name_bwd(c)
            end

            if v in (0, 1) && c != griditem.channel_name
                griditem.channel_name = c
                changed = true
            end
        elseif k == "background_correction"
            vs = (griditem.type == SpmGridImage) ? background_correction_list_image : background_correction_list_spectrum
            if v in keys(vs) && v != griditem.background_correction
                griditem.background_correction = v
                changed = true
            end
        elseif k == "colorscheme" && griditem.type == SpmGridImage
            if v == "_invert"
                v = griditem.colorscheme
                if endswith(v, " inv")
                    v = v[1:end-4]
                else
                    v *= " inv"
                end
            end
            if v in keys(colorscheme_list) && v != griditem.colorscheme
                griditem.colorscheme = v
                changed = true
            end
        elseif k == "edits"
            if griditem.edits != v
                cache_safe = false
                changed = true  # always recreate in case of edits (for now)
            end
            griditem.edits = v
        end
    end
    return changed, cache_safe
end


"""Cycles the channel, switches direction (backward/forward), changes background correction, changes colorscheme, or inverts colorscheme
for the images/spectra specified by ids. The type of change is specified by the argument "what".
The argument "jump" specifies whether to cycle backward or forward (if applicable).
The argument "full_resolution" specifies whether the images will be served in full resolution or resized to a smaller size.
Modifies the griditems array."""
function change_griditem!(griditems::Dict{String,SpmGridItem}, ids::Vector{String}, dir_data::String, what::Union{String,Dict}, full_resolution::Bool, jump::Int=0)::Nothing
    dir_cache = get_dir_cache(dir_data)
    Threads.@threads for id in ids
        griditem = griditems[id]
        filename_original_full = joinpath(dir_data, griditem.filename_original)
        if griditem.type == SpmGridImage
            item = load_image_memcache(filename_original_full)
        elseif griditem.type == SpmGridSpectrum
            item = load_spectrum_memcache(filename_original_full)
        else
            println("Unknown type: ", griditem.type)  # this should never happen, though
            continue
        end

        # we need all channel names to change GXSM files
        if is_gxsm_image(griditem) 
            channel_names_before = item.channel_names
            item.channel_names = get_gxsm_channel_names(griditem)
        end
        changed, cache_safe = pre_change_griditem!(griditem, item, what, jump)
        # change back now
        if is_gxsm_image(griditem) 
            item.channel_names = channel_names_before
        end

        # GXSM files have multiple files, so we have to load the right one
        # if the filename_original was changed (can happen for GXSM files), we have to reload the item
        if is_gxsm_image(griditem)
            filename_original_before = griditem.filename_original
            change_gxsm_griditem_filename_original!(griditem, griditems[id].channel_name)

            if griditem.filename_original != filename_original_before
                filename_original_full = joinpath(dir_data, griditem.filename_original)
                if griditem.type == SpmGridImage
                    item = load_image_memcache(filename_original_full)
                elseif griditem.type == SpmGridSpectrum
                    item = load_spectrum_memcache(filename_original_full)
                end
            end
        end
        full_resolution && (changed = true)  # always recreate in full resolution

        !changed && continue

        # update the image or spectrum
        if griditem.type == SpmGridImage
            resize_to_ = full_resolution ? 0 : resize_to
            create_image!(griditem, item, resize_to=resize_to_, dir_cache=dir_cache, cache_safe=cache_safe)    
        elseif griditem.type == SpmGridSpectrum
            create_spectrum!(griditem, item, dir_cache=dir_cache, cache_safe=cache_safe)
        end
    end
    return nothing
end


"""Resets basic image/spectrum parameters to their default values"""
function reset_griditem!(griditems::Dict{String,SpmGridItem}, ids::Vector{String}, dir_data::String, full_resolution::Bool)::Nothing
    dir_cache = get_dir_cache(dir_data)
    Threads.@threads for id in ids
        griditem = griditems[id]
        filename_original_full = joinpath(dir_data, griditem.filename_original)

        if griditem.type == SpmGridImage
            item = load_image_memcache(filename_original_full)
        elseif griditem.type == SpmGridSpectrum
            item = load_spectrum_memcache(filename_original_full)
        else
            println("Unknown type: ", griditem.type)  # this should never happen, though
            continue
        end
    
        changed = reset_default!(griditem, item)

        # update the image or spectrum
        if changed
            if griditem.type == SpmGridImage
                resize_to_ = full_resolution ? 0 : resize_to
                create_image!(griditem, item, resize_to=resize_to_, dir_cache=dir_cache)    
            elseif griditem.type == SpmGridSpectrum
                create_spectrum!(griditem, item, dir_cache=dir_cache)
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

        # GXSM files have multiple files, so we have to load the right one
        change_gxsm_griditem_filename_original!(griditem, griditems[id_from].channel_name)

        filename_original_full = joinpath(dir_data, griditem.filename_original)
        if griditem.type == SpmGridImage
            item = load_image_memcache(filename_original_full)
            properties = [:channel_name, :background_correction, :edits, :colorscheme, :channel_range_selected]
        elseif griditem.type == SpmGridSpectrum
            item = load_spectrum_memcache(filename_original_full)
            properties = [:channel_name, :channel_unit, :channel2_name, :channel2_unit, :scan_direction, :background_correction, :edits, :channel_range_selected]
        end

        changed = false
        cache_safe = true
        for p in properties
            v = getfield(griditems[id_from], p)

            if p in [:channel_name, :channel2_name]  # for channels we have to make sure that these channels exist
                v in item.channel_names || continue
            end

            if v != getfield(griditem, p)
                setfield!(griditem, p, v)
                changed = true
                if (p == :edits) && changed
                    cache_safe = false
                end
            end
        end

        # update the image or spectrum
        if changed
            if griditem.type == SpmGridImage
                resize_to_ = full_resolution ? 0 : resize_to
                create_image!(griditem, item, resize_to=resize_to_, dir_cache=dir_cache, cache_safe=cache_safe)    
            elseif griditem.type == SpmGridSpectrum
                create_spectrum!(griditem, item, dir_cache=dir_cache, cache_safe=cache_safe)
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
    extra_info["active_edits_str"] = get_active_edits_str(griditem)
    if griditem.type == SpmGridImage
        im_spm = load_image(filename_original_full, header_only=true, output_info=0)
        if is_gxsm_image(griditem)  # we are not loading all images here, so we have to set the channel names manually
            im_spm.channel_names = get_gxsm_channel_names(griditem)
            im_spm.channel_units = fill("", length(im_spm.channel_names))
        end
        channel_names, channel_units = sort_channel_names_units(im_spm.channel_names, im_spm.channel_units)
        extra_info["Channels"] = join(channel_names, ", ")
        extra_info["Units"] = join(channel_units, ", ")
        return im_spm.header, extra_info
    elseif griditem.type == SpmGridSpectrum
        add_index_column = is_gxsm_spectrum(filename_original_full) ? false : true  # GXSM files already have an index column
        spectrum = load_spectrum(filename_original_full, header_only=true, index_column=add_index_column)  # no caching here
        channel_names, channel_units = sort_channel_names_units(spectrum.channel_names, spectrum.channel_units)
        extra_info["Channels"] = join(channel_names, ", ")
        extra_info["Units"] = join(channel_units, ", ")
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
function update_virtual_copies_order!(virtual_copies::Vector{SpmGridItem}, id::String)::Int
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
function parse_files(dir_data::String, w::Union{Window,Nothing}=nothing;
    only_new::Bool=false, force_ids::Vector{String}=String[], output_info::Int=1)::Tuple{Dict{String, SpmGridItem},Vector{String},Dict{String, Vector{String}}}

    time_start = Dates.now()

    dir_cache = get_dir_cache(dir_data)
    if !isdir(dir_cache)
        mkpath(dir_cache)
    end

    # load saved data - if available
    griditems, channel_names_list = load_all(dir_data, w)

    griditems_new = String[]
    virtual_copies_dict = Dict{String, Vector{SpmGridItem}}()
    if !only_new
        # get all virtual copies that are saved
        virtual_copies_dict = get_virtual_copies_dict(griditems)
        
        # set all status to -2 (will be then re-set to 0 when the file is found in the directory)
        map(x -> x.status=-2, values(griditems))  # we do not need to use "map! (we even cant use it)
    end

    datafiles = filter!(x -> isfile(x) && (is_image(x) || is_spectrum(x)), readdir(dir_data, join=true))
    if w !== nothing && length(datafiles) > 1  # 1 files will have the plural-s problem in the frontend, so just skip it
        @js_ w page_start_load_params($(length(datafiles)))
    end

    # we need to sort the datafiles by extension first, then by name (otherwise the gxsm multiple files can be out of order - e.g. some spectrum files could be inbetween the image files)
    sort!(datafiles, by = x -> (splitext(x)[2], x))

    empty!(channel_names_files)

    num_parsed = 0
    num_errors = 0
    num_in_cache = 0
    tasks = Task[]
    datafiles_curr = String[]
    i_datafile = 0
    while i_datafile < length(datafiles)
        i_datafile += 1
        datafile = datafiles[i_datafile]
        push!(datafiles_curr, datafile)

        # gxsm uses one file for each channel
        if is_gxsm_image(datafile) && i_datafile < length(datafiles) && base_filename(datafiles[i_datafile+1]) == base_filename(datafile)
            continue
        end

        # first one is the main file
        datafile = datafiles_curr[1]
        filename_original = basename(datafile)
        id = base_filename(filename_original)
        is_gxsm_image(filename_original) && (channel_names_files[id] = get_channels_names_files(datafiles_curr))

        # there can be multiple files (for GXSM), so we compute the mean
        s = stat.(datafiles_curr)
        ctime = mean(getfield.(s, :ctime))
        mtime = mean(getfield.(s, :mtime))
        created = unix2datetime(ctime)
        last_modified = unix2datetime(mtime)

        if only_new && haskey(griditems, id) && id ∉ force_ids
            empty!(datafiles_curr)
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
        if haskey(griditems, id) && griditems[id].last_modified == last_modified &&  # && griditems[id].created == created 
            griditem_cache_up_to_date(griditem_and_virtual_copies, dir_cache) && haskey(channel_names_list, id) &&
            id ∉ force_ids

            griditems[id].status = 0
            num_in_cache += 1
            if haskey(virtual_copies_dict, id)
                for virtual_copy in virtual_copies_dict[id]
                    griditems[virtual_copy.id].status = 0
                    num_in_cache += 1
                end
            end
        else
            use_existing = id in force_ids ? false : true
            if is_image(filename_original)
                # we load all datafiles here (for gxsm)
                ts, err = parse_image!(griditems, virtual_copies_dict, griditems_new, channel_names_list, only_new, use_existing,
                    dir_cache, datafiles_curr, id, created, last_modified)
            elseif is_spectrum(filename_original)
                ts, err = parse_spectrum!(griditems, virtual_copies_dict, griditems_new, channel_names_list, only_new, use_existing,
                    dir_cache, datafile, id, created, last_modified)
            end
            if err != ""
                println(err)
                num_errors += 1
            else
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
        empty!(datafiles_curr)
    end
    wait.(tasks)

    elapsed_time = Dates.now() - time_start
    if output_info > 0
        num_items = length(filter(x -> x.status >= 0, collect(values(griditems))))
        err_num_str = (num_errors > 0) ? ", $(num_errors) errors" : ""
        msg = "Parsed $(num_parsed) files ($(num_items) items, $(num_in_cache) in cache$(err_num_str)) in $elapsed_time."
        log(msg, w)
    end
    cleanup_channel_names_list!(channel_names_list, griditems)
    return griditems, griditems_new, channel_names_list
end


"""removes all channels from `channels_names_list` that are not in the griditems"""
function cleanup_channel_names_list!(channels_names_list::Dict{String, Vector{String}}, griditems::Dict{String,SpmGridItem})
    valid_keys = Set{String}([base_filename(im.filename_original) for im in values(griditems)])
    for k in keys(channels_names_list)
        if k ∉ valid_keys
            delete!(channels_names_list, k)
        end
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


"""Loads html from files and assembles into one file"""
function read_html_files(fname::String)
    s = open(fname) do file
        read(file, String)
    end

    ms = eachmatch(r"{{{([^}]*)}}}", s)
    for m in ms
        fname2 = m.captures[1]
        s2 = read_html_files(path_asset(string(fname2)))
        s = replace(s, m.match => s2)
    end

    return s
end


"""loads html from a file into a div.htmlimport - this is then loaded into the document body by the js function `load_page`"""
function loadhtml!(w::Window,  fname::String)::Nothing
    s = read_html_files(fname)

    expr = JSExpr.@js begin
        @var el = document.createElement("div")
        el.style.display = "none"
        el.className = "htmlimport"
        el.innerHTML = $s
        document.body.appendChild(el)
    end

    Blink.js(w, expr, callback=true)
    return nothing
end


"""Loads images in specific directory"""
function load_directory(dir_data::String, w::Window; output_info::Int=1)::Nothing
    # parse images etc
    global cancel_sent = false  # user might send cancel during the next step

    # remove old cache
    global memcache_images = ListNodeCache{SpmImage}(memcache_mb_images)
    global memcache_spectra = ListNodeCache{SpmSpectrum}(memcache_mb_spectra)

    griditems, _, channel_names_list = parse_files(dir_data, w, output_info=output_info)
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
    dir_temp_cache = get_dir_temp_cache(dir_data)
    dir_cache_js = add_trailing_slash(dir_cache)
    dir_temp_cache_js = add_trailing_slash(dir_temp_cache)
    dir_colorbars_js = add_trailing_slash(joinpath(dir_cache, dir_colorbars))
    dir_edits = add_trailing_slash(get_dir_edits(dir_cache))
    @js_ w set_params_project($dir_data_js, $dir_cache_js, $dir_temp_cache_js, $dir_colorbars_js, $dir_edits, $filenames_colorbar)
    
    # only send the images with status >=0 (deleted ones are not sent, but still saved)
    griditems_values = NaturalSort.sort!(filter(im->im.status >= 0, collect(values(griditems))), by=im -> (im.recorded, im.filename_original, im.virtual_copy))  # NaturalSort will sort number suffixes better
    json_compressed = transcode(GzipCompressor, JSON.json(griditems_values))
    @js_ w load_images($json_compressed, $bottomleft, $topright, true)

    griditems_values_temp_cache = filter(im -> im.status === 10, griditems_values)
    if length(griditems_values_temp_cache) > 0
        fname_temp_cache = map(griditems_values_temp_cache) do im
            return im.filename_display
        end
        @js_ w load_notification_temp_cache($fname_temp_cache)
    end

    set_event_handlers(w, dir_data, Dict("griditems" => griditems, "channel_names_list" => channel_names_list))

    save_config(dir_data)  # set and save new last dirs
    @js_ w set_last_directories($last_directories)

    Blink.progress(w, -1)

    return nothing
end


"""Start the main GUI and loads images from dir_data (if specified)"""
function tycoon(dir_data::String=""; return_window::Bool=false, keep_alive::Bool=true)::Union{Window,Nothing}
    global Precompiling = false
    
    file_logo = path_asset("media/logo_diamond.png")
    w = Window(Dict(
        "webPreferences" => Dict(
            "webSecurity" => false,  # to load local files
            "nodeIntegration" => true,  # for require("..") within the renderer process
            "contextIsolation" => false  # for require("..") within the renderer process
        ),
        "title" => "SpmImage Tycoon",
        "icon" => file_logo,
        :icon => file_logo,
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
    
    bg_corrections = Dict(
        "image" => keys(background_correction_list_image),
        "spectrum" => keys(background_correction_list_spectrum),
    )
    directions_list = Dict(
        "image" => Dict("0" => "forward", "1" => "backward"),
        "spectrum" => Dict("0" => "forward", "1" => "backward", "2" => "both")
    )

    @js w set_params($dir_asset, $auto_save_minutes, $overview_max_images, $bg_corrections, $directions_list, $editing_entries, $tycoon_mode)
    @js w set_last_directories($last_directories)
    @js w load_page($versions)
    @js w show_start()

    set_event_handlers_basic(w)

    global exit_tycoon = false

    if dir_data != ""
        load_directory(abspath(dir_data), w)
    end
    
    # bring window to front
    Blink.AtomShell.@dot w show()

    if keep_alive
        while !exit_tycoon
            yield()
            sleep(0.1)
        end
        # close and exit after a few seconds
        sleep(5)
        close(w, quit=true)
    end
    if return_window
        return w
    else
        return nothing
    end
end


@setup_workload begin
    global Precompiling = true
    fname_spec_base = "Z-Spectroscopy420.dat"
    fname_img_base = "Image_002.sxm"
    fname_spec = joinpath(@__DIR__ , "../test/data/", fname_spec_base)
    fname_img = joinpath(@__DIR__ , "../test/data/", fname_img_base)
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
    bg_corrections = Dict(
        "image" => keys(background_correction_list_image),
        "spectrum" => keys(background_correction_list_spectrum),
    )
    directions_list = Dict(
        "image" => Dict("0" => "forward", "1" => "backward"),
        "spectrum" => Dict("0" => "forward", "1" => "backward", "2" => "both")
    )
    include(joinpath(@__DIR__ , "../test/functions.jl"))

    @compile_workload begin
        global Precompiling = true
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

        load_config()
        if length(colorscheme_list) != 2*length(colorscheme_list_pre)  # only re-generate if necessary
            generate_colorscheme_list!(colorscheme_list, colorscheme_list_pre)  # so we have 1024 steps in each colorscheme - also automatically create the inverted colorschemes
        end

        SpmImageTycoon.load_all(DIR_db_old, nothing)
        griditems, _, _ = SpmImageTycoon.parse_files(DIR_data)
        # these can give write permission errors, so let's remove for now
        # SpmImageTycoon.create_spectrum!(griditems[fname_spec_base], spec, dir_cache=DIR_cache)
        # SpmImageTycoon.create_image!(griditems[fname_img_base], ima, dir_cache=DIR_cache)
        SpmImageTycoon.get_spectrum_data_dict(griditems[fname_spec_base], DIR_data)
        try  # there might be some write errors, so let's wrap it in a try-block
            state = Dict{String, Any}("edits" => Any[
                "{\"id\":\"FTF\",\"n\":\"1\",\"off\":0,\"exp\":1,\"pars\":{\"ps\":[144,144],\"mf\":[0.5,0.5],\"f\":\"r\",\"w\":\"\",\"wf\":1,\"s\":\"ln\",\"d\":\"a\",\"r\":[[444779,97294],[516654,197127],[538510,19546],[615733,114572],[919854,21529],[919854,21529]]}}",
                "{\"id\":\"FTF\",\"n\":\"2\",\"off\":0,\"exp\":1,\"pars\":{\"ps\":[144,144],\"mf\":[0.5,0.5],\"f\":\"p\",\"w\":\"hn\",\"wf\":1,\"s\":\"li\",\"d\":\"r\",\"r\":[[282630,209644],[443513,402923]]}}",
                "{\"id\":\"G\",\"n\":\"3\",\"off\":0,\"exp\":1,\"pars\":{\"s\":0.05}}"],
                "channel_name" => "Frequency Shift", "background_correction" => "none"
            )
            SpmImageTycoon. change_griditem!(griditems, ["Image_004.sxm"], DIR_data, state, true)
        catch e
            
        end

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

        loadhtml!(w, file_GUI)
        filter!(
            x -> isfile(x) && (endswith(x, ".css") || endswith(x, ".js")),
            asset_files
            )
            for asset_file in asset_files
                load!(w, asset_file)
            end

        @js w set_params($dir_asset, 0, 100, $bg_corrections, $directions_list, $editing_entries, "")
        @js w load_page($versions)
        @js w show_start()
        
        set_event_handlers_basic(w)
        
        delete_files(;dir_cache=DIR_cache, fname_odp=FNAME_odp)
        load_directory(abspath(DIR_data), w, output_info=0)
        
        selected = ["Image_004.sxm"]
        sel = selector(selected)
        # send_hover_mouse(sel, send_event=false, window=w)
        
        @js w get_image_info("Image_004.sxm")
        
        selected = ["Image_002.sxm", "Image_004.sxm"]
        sel = selector(selected)
        send_click(sel, window=w)
        send_key(["b", "b", "b", "b", "b", "c", "c", "i", "p"], window=w)
        
        @js w toggle_imagezoom("zoom", "Image_004.sxm")
        send_key("t", window=w)

        # send_key(["ArrowRight"], window=w)  # this seems to sometimes hang, seems a bit like in compilation mode the spectrum display hangs

        start = Dict(:x => 1.2, :y => 1.2)
        stop = Dict(:x => 2.4, :y => 2.4)
        @js w get_line_profile("Image_398.sxm", $start, $stop, 0.2)

        items = get_items(window=w)
        close(w, quit=true)
        return nothing
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