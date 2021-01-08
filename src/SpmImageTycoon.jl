__precompile__()

module SpmImageTycoon

using Blink
using ColorSchemes
using DataStructures
using Dates
using Images
using ImageIO
using JLD2
using JSON
using NaturalSort
using StatsBase
using SpmImages

export SpmImageGridItem, tycoon

mutable struct SpmImageGridItem_v12
    id::String                               # id (will be filename and suffixes for virtual copies)
    filename_original::String                # original filename (.sxm)
    created::DateTime                        # file creation date
    last_modified::DateTime                  # file last modified date
    recorded::DateTime                       # date recorded
    filename_display::String                 # generated png image
    channel_name::String                     # channel name (" bwd" indicates backward direction)
    channel_unit::String                     # unit for the respective channel
    scansize::Vector{Float64}                # scan size in physical units
    scansize_unit::String                    # scan size unit
    comment::String                          # comment in the file
    background_correction::String            # type of background correction used
    colorscheme::String                      # color scheme
    channel_range::Vector{Float64}           # min/max of current channel
    channel_range_selected::Vector{Float64}  # selected min/max for current channel
    filters::Vector{String}                  # array of filters used (not implemented yet)
    keywords::Vector{String}                 # keywords
    rating::Int                              # rating (0 to 5 stars)
    status::Int                              # status, i.e. 0: normal, -1: deleted by user, -2: deleted on disk (not implemented yet)
    virtual_copy::Int                        # specifies whether this is a virtual copy, i.e. 0: original image, >=1 virtual copies (not implemented yet)

    SpmImageGridItem_v12(; id="", filename_original="", created=DateTime(0), last_modified=DateTime(0), recorded=DateTime(0), filename_display="",
        channel_name="", channel_unit="", scansize=[], scansize_unit="", comment="", background_correction="none", colorscheme="gray",
        channel_range=[], channel_range_selected=[], filters=[], keywords=[], rating=0, status=0, virtual_copy=0) =
    new(id, filename_original, created, recorded, last_modified, filename_display,
        channel_name, channel_unit, scansize, scansize_unit, comment, background_correction, colorscheme,
        channel_range, channel_range_selected, filters, keywords, rating, status, virtual_copy)
end
SpmImageGridItem = SpmImageGridItem_v12


include("config.jl")
include("export.jl")


"""saves all colorbars as pngs in the cache directory.
Returns a dictionary that associates each colorscheme name with a png file"""
function save_colorbars(dict_colorschemes::OrderedDict{String,ColorScheme}, dir_data::String, width::Int=512, height::Int=20)::Dict{String,String}
    dir_cache = get_dir_cache(dir_data)
    res = Dict()
    for (k,v) in dict_colorschemes
        m = repeat(transpose(collect(0:1/(width-1):1)), inner=(height,1))
        img = get(v, m)
        fname = k * ".png"
        save(joinpath(dir_cache, dir_colorbars, fname), img)      # you'll need FileIO or similar to do this
        res[k] = fname
    end

    return res
end


"""scales and offsets an array, so that each value lies between 0 and 1.
If range_selected is given, this range is normalized to lie between 0 and 1.
Returns the minimum and maximum value of the original array."""
function normalize01!(d::AbstractArray; range_selected::Array{<:Number}=Float64[])::Tuple{Number,Number}
    d_ = filter(!isnan, d)
    vmin_original, vmax_original = minimum(d_), maximum(d_)  # minimum and maximum function return NaN otherwise
    if vmin_original == vmax_original
        d .= 0
    else
        vmin, vmax = vmin_original, vmax_original
        if length(range_selected) == 2 && range_selected[1] != range_selected[2]
            span = vmax - vmin
            vmax = vmin + span * range_selected[2]
            vmin += span * range_selected[1]
        end
        d[:] = (d .- vmin) ./ (vmax - vmin)
    end
    return vmin_original, vmax_original
end


"""calculates the histogram for the image specified by id.
Returns the bin width (normalized for bin positions between 0 and 1) and relative bin counts."""
function get_histogram(id::String, dir_data::String, images_parsed::Dict{String, SpmImageGridItem})::Tuple{Float32,Vector{Float32}}
    im_spm = load_image(joinpath(dir_data, images_parsed[id].filename_original), output_info=0)
    d = vec(get_image_data(images_parsed[id], im_spm, resize_to=resize_to, normalize=false, clamp=false)[1])

    filter!(!isnan, d)
    normalize01!(d)  # we normalize here, otherwise the hist generation does not seem to be robust
    # clamp01nan!(d)
    N = length(d)
    # nbins = min(ceil(Int, sqrt(N)), 256)
    nbins = 256
    hist = StatsBase.fit(StatsBase.Histogram, d, nbins=nbins)  # the function will give "approximate" number of bins

    counts = hist.weights ./ maximum(hist.weights)
    # normalize width so that the bin-positions are between 0 and 1
    hist_range = hist.edges[1]  # 1 because it gives out a tuple
    width = step(hist_range)

    return width, counts
end


"""adds a trailing slash to a directory if necessary"""
function add_trailing_slash(directory::String)::String
    return joinpath(directory, "")
end


"""get contents of filename"""
function get_contents(filename::String)::String
    contents = open(file_GUI) do file
        read(file, String)
    end
    return contents
end


"""returns the cache directory (which is a subdirectory of dir_data"""
function get_dir_cache(dir_data::String)::String
    return joinpath(dir_data, dir_cache_name)
end


"""Returns the absolute path to an asset"""
function path_asset(asset::String)::String
    return abspath(joinpath(@__DIR__, dir_res, asset))
end


"""gets the default channel name (according to the lists channels_feedback_on and channels_feedback_off) and the z-feedback status of image."""
function default_channel_name(image::SpmImage, channels_feedback_on::Vector{String}, channels_feedback_off::Vector{String})::String
    channel_name = ""
    if image.z_feedback
        channels = channels_feedback_on
    else
        channels = channels_feedback_off
    end
    for c in channels
        if c in image.channel_names
            channel_name = c
            break
        end
    end
    if channel_name == ""
        channel_name = image.channel_names[1]
    end
    return channel_name
end


"""Gets the channel name after current_channel_name in the list of image's channel names."""
function next_channel_name(image::SpmImage, current_channel_name::String, jump::Int)::String
    backward_suffix = ""
    if endswith(current_channel_name, " bwd")
        current_channel_name = current_channel_name[1:end-4]
        backward_suffix = " bwd"
    end
    i = findfirst(x -> x == current_channel_name, image.channel_names)
    if i === nothing  # this should never happen anyways
        return image.channel_names[1]
    else
        i = (i + jump - 1) % length(image.channel_names) + length(image.channel_names)
        i = i % length(image.channel_names) + 1
        return image.channel_names[i] * backward_suffix
    end
end


"""Gets the next background_correction key in the list of possible background corrections"""
function next_background_correction(background_correction::String, jump::Int)::String
    keys_bg = collect(keys(background_correction_list))
    i = findfirst(x -> x == background_correction, keys_bg)
    i = (i + jump - 1) % length(background_correction_list) + length(background_correction_list)
    i = i % length(background_correction_list) + 1
    return keys_bg[i]
end


"""Gets the next colorscheme key in the list of possible colorschemes"""
function next_colorscheme(colorscheme::String, jump::Int)::String
    keys_cs = collect(keys(colorscheme_list))
    i = findfirst(x -> x == colorscheme, keys_cs)
    i = (i + sign(jump) + jump - 1) % length(colorscheme_list) + length(colorscheme_list)   # inverted and normal are alternating, so an extra +1 or -1 (i.e. sign(jump) is needed
    i = i % length(colorscheme_list) + 1
    return keys_cs[i]
end


"""Gets the inverted colorscheme key in the list of possible colorschemes"""
function invert_colorscheme(colorscheme::String)::String
    if endswith(colorscheme, " inv")
        return colorscheme[1:end-4]
    else
        return colorscheme * " inv"
    end
end


"""gives a colorscheme to an 2D grayscale image (i.e. and image with values between 0 and 1)"""
function colorize(data::Array{<:Number,2}, colorscheme::String)::Array{RGB{Float32},2}
    m, n = size(data)
    cs = colorscheme_list[colorscheme]
    res = Array{RGB{Float32}}(undef, m, n)
    for j in 1:n, i in 1:m
        @views @inbounds res[i,j] = getindex(cs, round(Int, data[i,j] * (length(cs) - 1)) + 1)
    end
    res
end


"""Get, resize, background correct and filter image data for a specific griditem. Returns a 2d array, the channel unit, minimum and maximum values."""
function get_image_data(griditem::SpmImageGridItem, im_spm::SpmImage; resize_to::Int=0, normalize::Bool=true, clamp::Bool=false)::Tuple{Array{Float32,2},String,Float32,Float32}
    channel = get_channel(im_spm, griditem.channel_name, origin="upper");
    d = channel.data
    unit = channel.unit

    ratio = min(1, resize_to / max(im_spm.pixelsize...))
    if ratio <= 0.0
        ratio = 1
    end
    if ratio < 1
        d = imresize(d, ratio=ratio)
    end

    d = correct_background(d, background_correction_list[griditem.background_correction])
    if normalize
        vmin, vmax = normalize01!(d, range_selected=griditem.channel_range_selected)  # normalize each value in the array to values between 0 and 1
    else
        vmin, vmax = 0, 0  # we only need it when also normalizing it
    end
    if clamp
        clamp01nan!(d)
    end

    return d, unit, vmin, vmax
end


"""Creates and saves a png image from the specified channel_name in the image. If necessary, the image size is decreased to the specified size.
The "filename_display" field of the SpmImageGridItem is updated (to the png filename without the directory prefix)"""
function create_image!(griditem::SpmImageGridItem, im_spm::SpmImage; resize_to::Int=0, base_dir::String="")
    # create grayscale image
    d, unit, vmin, vmax = get_image_data(griditem, im_spm, resize_to=resize_to, normalize=true, clamp=true)
    griditem.channel_unit = unit
    griditem.channel_range = [vmin, vmax]

    if griditem.colorscheme == "gray"  # special case, we dont need the actual colorscheme
        im_arr = Gray.(d)
    else
        im_arr = colorize(d, griditem.colorscheme)
    end
    
    filename_display = "$(griditem.filename_original[1:end-4])_$(griditem.virtual_copy).png"
    save(joinpath(base_dir, filename_display), im_arr)  # ImageIO should be installed, gives speed improvement for saving pngs

    griditem.filename_display = filename_display
    return nothing
end


"""Loads the header data for an image and returns a dictionary with all the data"""
function get_image_header(id::String, dir_data::String, images_parsed::Dict{String,SpmImageGridItem})::OrderedDict{String,String}
    filename_original = images_parsed[id].filename_original
    im_spm = load_image(joinpath(dir_data, filename_original), header_only=true, output_info=0)
    return im_spm.header
end


"""sets keywords"""
function set_keywords!(ids::Vector{String}, dir_data::String, images_parsed::Dict{String,SpmImageGridItem}, mode::String, keywords::Vector{String})
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


"""sets selected range and recreates images"""
function set_range_selected!(ids::Vector{String}, dir_data::String, images_parsed::Dict{String,SpmImageGridItem}, range_selected::Array{Float64}, full_resolution::Bool)
    dir_cache = get_dir_cache(dir_data)
    for id in ids  # we could use threads here as well, but so far we only do this for one image at once (and threads seem to make it a bit more unstable)
        filename_original = images_parsed[id].filename_original
        im_spm = load_image(joinpath(dir_data, filename_original), output_info=0)
        images_parsed[id].channel_range_selected = range_selected
        resize_to_ = full_resolution ? 0 : resize_to
        create_image!(images_parsed[id], im_spm, resize_to=resize_to, base_dir=dir_cache)
    end
end


"""Cycles the channel, switches direction (backward/forward), changes background correction, changes colorscheme, or inverts colorscheme
for the images specified by ids. The type of change is specified by the argument "what".
The argument "jump" specifies whether to cycle backward or forward (if applicable).
The argument "full_resolution" specifies whether the images will be served in full resolution or resized to a smaller size.
Modifies the images_parsed array."""
function switch_channel_direction_background!(ids::Vector{String}, dir_data::String, images_parsed::Dict{String,SpmImageGridItem}, what::String, jump::Int, full_resolution::Bool)
    dir_cache = get_dir_cache(dir_data)
    Threads.@threads for id in ids
        filename_original = images_parsed[id].filename_original
        im_spm = load_image(joinpath(dir_data, filename_original), output_info=0)
        channel_name = images_parsed[id].channel_name
        background_correction = images_parsed[id].background_correction
        colorscheme = images_parsed[id].colorscheme
        if what == "channel"
            channel_name = next_channel_name(im_spm, channel_name, jump)
            images_parsed[id].channel_name = channel_name
            images_parsed[id].channel_range_selected = [] # reset selected range when switching channel (we try to keep it for all other cases for now)
        elseif what == "direction"
            if endswith(channel_name, " bwd")
                channel_name = channel_name[1:end-4]
            else
                channel_name = channel_name * " bwd"
            end
            images_parsed[id].channel_name = channel_name
        elseif what == "background_correction"
            background_correction = next_background_correction(background_correction, jump)
            images_parsed[id].background_correction = background_correction
        elseif what == "colorscheme"
            colorscheme = next_colorscheme(colorscheme, jump)
            images_parsed[id].colorscheme = colorscheme
        elseif what == "inverted"
            colorscheme = invert_colorscheme(colorscheme)
            images_parsed[id].colorscheme = colorscheme
        end
        resize_to_ = full_resolution ? 0 : resize_to
        create_image!(images_parsed[id], im_spm, resize_to=resize_to, base_dir=dir_cache)
    end
    return nothing
end


"""returns a subset of the dictionary parsed_images. this can then be passed to the js"""
function get_subset(images_parsed::Dict{String, SpmImageGridItem}, ids::Vector{String})::OrderedDict{String, SpmImageGridItem}
    images_parsed_sub = OrderedDict{String, SpmImageGridItem}()
    map(ids) do id
        images_parsed_sub[id] = images_parsed[id]
    end
    return images_parsed_sub
end


"""gets a dictionary "original_id" => (array of virtual copies) with all virtual copies in images_parsed"""
function get_virtual_copies_dict(images_parsed::Dict{String, SpmImageGridItem})::Dict{String,Array{SpmImageGridItem}}
    virtual_copies = filter(x -> last(x).virtual_copy > 0, images_parsed)
    virtual_copies_dict = Dict{String, Array{SpmImageGridItem}}()  # create a dict for quick lookup
    for virtual_copy in values(virtual_copies)
        id_original = virtual_copy.filename_original
        if !haskey(virtual_copies_dict, id_original)
            virtual_copies_dict[id_original] = Array{SpmImageGridItem}(undef, 0);
        end
        push!(virtual_copies_dict[id_original], virtual_copy)
    end

    return virtual_copies_dict
end


"""gets the virtual copies that have been created for id. Returns an array of SpmImageGridItem"""
function get_virtual_copies(images_parsed::Dict{String, SpmImageGridItem}, id::String)::Array{SpmImageGridItem}
    virtual_copies = filter(x -> last(x).filename_original==id && last(x).virtual_copy > 0, images_parsed)
    return collect(values(virtual_copies))
end


"""Generates a new unique id that is not yet present in images_parsed by appending numbers to the given id"""
function get_new_id(images_parsed::Dict{String, SpmImageGridItem},id_original::String)::String
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


"""Sets the virtual_copy-field values in the SpmImageGridItems to consecutive numbers (starting with 1). Creates a position to insert a new virtual copy (after the items with id 'id').
Returns the new position."""
function update_virtual_copies_order!(virtual_copies::Array{SpmImageGridItem}, id::String)::Int
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
function parse_files(dir_data::String, w::Window=nothing; output_info::Int=0)::Dict{String, SpmImageGridItem}
    dir_cache = get_dir_cache(dir_data)

    # load saved data - if available
    images_parsed = load_all(dir_data)

    # get all virtual copies that are saved
    virtual_copies_dict = get_virtual_copies_dict(images_parsed)
    
    # set all status to -2 (will be then re-set to 0 when the file is found in the directory)
    map(x -> x.status=-2, values(images_parsed))  # we do not need to use "map! (we even cant use it)
    
    datafiles = filter!(x -> isfile(x) && endswith(x, extension_spm), readdir(dir_data, join=true))
    if w !== nothing && length(datafiles) > 1  # 1 files will have the plural-s problem in the frontend, so just skip it
        @js_ w page_start_load_params($(length(datafiles)))
    end

    num_parsed = 0
    time_start = Dates.now()
    Threads.@threads for datafile in datafiles
        im_spm = load_image(datafile, output_info=0)
        
        filename_original = basename(datafile)
        created = unix2datetime(ctime(datafile))
        last_modified = unix2datetime(mtime(datafile))
        
        id = filename_original

        if haskey(images_parsed, id)
            # still update a few fields (the files may have changed) - but most of these fields should stay unchanged
            images_parsed[id].filename_original = filename_original
            images_parsed[id].created = created
            images_parsed[id].last_modified = last_modified
            images_parsed[id].recorded = im_spm.start_time
            images_parsed[id].scansize = im_spm.scansize
            images_parsed[id].scansize_unit = im_spm.scansize_unit
            images_parsed[id].comment = im_spm.header["Comment"]
            images_parsed[id].status = 0
        else
            # get the respective image channel (depending on whether the feedback was on or not)
            channel_name = default_channel_name(im_spm, channels_feedback_on, channels_feedback_off)
            images_parsed[id] = SpmImageGridItem(
                id=id, filename_original=filename_original, created=created, last_modified=last_modified, recorded=im_spm.start_time,
                channel_name=channel_name, scansize=im_spm.scansize, scansize_unit=im_spm.scansize_unit, comment=im_spm.header["Comment"]
            )
        end
        create_image!(images_parsed[id], im_spm, resize_to=resize_to, base_dir=dir_cache)

        # virtual copies
        if haskey(virtual_copies_dict, id)
            for virtual_copy in virtual_copies_dict[id]
                # update fields here, too - however, most of these fields should stay unchanged
                images_parsed[virtual_copy.id].filename_original = filename_original
                images_parsed[virtual_copy.id].created = created
                images_parsed[virtual_copy.id].last_modified = last_modified
                images_parsed[virtual_copy.id].recorded = im_spm.start_time
                images_parsed[virtual_copy.id].scansize = im_spm.scansize
                images_parsed[virtual_copy.id].scansize_unit = im_spm.scansize_unit
                images_parsed[virtual_copy.id].comment = im_spm.header["Comment"]
                images_parsed[virtual_copy.id].status = 0
                create_image!(images_parsed[virtual_copy.id], im_spm, resize_to=resize_to, base_dir=dir_cache)
            end
        end

        num_parsed += 1
        # indicate progress
        if num_parsed % show_load_progress_every == 0
            if w !== nothing
                progress = ceil(num_parsed / length(datafiles) * 100)
                @js_ w page_start_load_progress($progress)
            end
        end
    end

    # delete virtual copies that arent associated with anything anymore
    for (id_original, virtual_copies) in virtual_copies_dict
        for virtual_copy in virtual_copies
            if haskey(images_parsed, id_original)
                if images_parsed[virtual_copy.filename_original].status < 0
                    delete!(images_parsed, virtual_copy.id)
                end
            else  # this should never happen, though
                delete!(images_parsed, virtual_copy.id)
            end
        end
    end

    elapsed_time = Dates.now() - time_start
    if output_info > 0
        println("Parsed $(length(images_parsed)) files in $elapsed_time.")
    end
    return images_parsed
end


"""load data from saved file"""
function load_all(dir_data::String)::Dict{String, SpmImageGridItem}
    dir_cache = get_dir_cache(dir_data)
    images_parsed = Dict{String, SpmImageGridItem}()
    
    f = joinpath(get_dir_cache(dir_data), filename_db)
    if isfile(f)
        JLD2.@load f images_parsed_save

        if length(images_parsed_save) == 0
            return images_parsed
        end

        first_value = first(values(images_parsed_save))
        t_save = typeof(first_value)
        if t_save <: Pair # JLD2 apparently reconstructs an array of pairs{id, SpmImageGridItem}
            t_save = typeof(first_value[2])
        end

        if t_save != SpmImageGridItem  # there was a change in the struct specification, lets try to copy field by field
            print("Old database detected. Converting... ")
            fieldnames_save = fieldnames(t_save)
            fieldnames_common = filter(x -> x in fieldnames_save, fieldnames(SpmImageGridItem))

            for pair in images_parsed_save  # JLD2 apparently reconstructs an array of pairs{id, SpmImageGridItem}
                id = pair[1]
                griditem = pair[2]
                images_parsed[id] = SpmImageGridItem()
                for f in fieldnames_common
                    setfield!(images_parsed[id], f, getfield(griditem, f))
                end
            end

            println("ok.")
        else
            images_parsed = images_parsed_save
        end
    end

    return images_parsed
end


"""saves the images_parsed dictionary to file"""
function save_all(dir_data::String, images_parsed::Dict{String, SpmImageGridItem})
    f = joinpath(get_dir_cache(dir_data), filename_db)
    JLD2.@save f images_parsed_save=images_parsed
    return nothing
end


"""sets the julia handlers that are triggered by javascript events"""
function set_event_handlers(w::Window, dir_data::String, images_parsed::Dict{String,SpmImageGridItem})
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
            image_header = get_image_header(id, dir_data, images_parsed)
            k = replace.(collect(keys(image_header)), ">" => "><wbr>")[3:end]  # replace for for word wrap in tables
            v = replace.(collect(values(image_header)), "\n" => "<br />")[3:end]  # the first two rows are not useful to display, so cut them off
            image_header_json = JSON.json(vcat(reshape(k, 1, :), reshape(v, 1, :)))
            @js_ w show_info($id, $image_header_json);
            if histogram
                width, counts = get_histogram(id, dir_data, images_parsed)
                @js_ w show_histogram($id, $width, $counts)
            end
        elseif what[1:5] == "next_"
            lock(l)
            jump = args[3]
            full_resolution = args[4]
            try
                switch_channel_direction_background!(ids, dir_data, images_parsed, what[6:end], jump, full_resolution)
                images_parsed_sub = get_subset(images_parsed, ids)
                @js_ w update_images($images_parsed_sub);
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
                    @js_ w update_images($images_parsed_sub);
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
                    @js_ w update_images($images_parsed_sub);
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
                    @js_ w update_images($images_parsed_sub);
                finally
                    unlock(l)
                end
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
                msg = ""
                if (:msg in fieldnames(typeof(e)))
                    msg = e.msg
                else
                    msg = typeof(e).name
                end
                @js_ w show_error($msg)
            finally
                unlock(l)
            end
        end
    end

    handle(w, "re_parse_images") do args
        lock(l)
        try
            save_all(dir_data, images_parsed)
            images_parsed = parse_files(dir_data)
            images_parsed_values = NaturalSort.sort!(collect(values(images_parsed)), by=im -> (im.recorded, im.filename_original, im.virtual_copy))  # NaturalSort will sort number suffixes better
            @js_ w load_images($images_parsed_values, true)
        finally
            unlock(l)
        end
    end

    handle(w, "save_all") do args
        lock(l)
        exit = args[1]  # TODO: close process when closing window
        try
            if dir_data != ""
                save_all(dir_data, images_parsed)
            end
            @js_ w saved_all()
        finally
            unlock(l)
        end
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
        finally
            unlock(l)
        end
    end

    handle(w, "debug") do args
        println("debug: " * string(args))
    end

    return nothing
end


"""Loads images in specific directory"""
function load_directory(dir_data::String, w::Window)
    # parse images etc
    filenames_colorbar = save_colorbars(colorscheme_list, dir_data)
    images_parsed = parse_files(dir_data, w)
    if length(images_parsed) == 0
        msg = "There are no SPM files in $dir_data"
        @js_ w page_start_load_error($msg)
        return nothing
    end

    # call js functions to setup everything
    dir_data_js = add_trailing_slash(dir_data)
    dir_cache = get_dir_cache(dir_data)
    dir_cache_js = add_trailing_slash(dir_cache)
    dir_colorbars_js = add_trailing_slash(joinpath(dir_cache, dir_colorbars))
    @js_ w set_params_project($dir_data_js, $dir_cache_js, $dir_colorbars_js, $filenames_colorbar)
    
    images_parsed_values = NaturalSort.sort!(collect(values(images_parsed)), by=im -> (im.recorded, im.filename_original, im.virtual_copy))  # NaturalSort will sort number suffixes better
    @js_ w load_images($images_parsed_values, true)

    set_event_handlers(w, dir_data, images_parsed)

    save_config(dir_data)  # set and save new last dirs
    @js_ w set_last_directories($last_directories)

    return nothing
end


"""Start the main GUI and loads images from dir_data (if specified)"""
function tycoon(dir_data::String="")::Window
    file_logo = path_asset("logo_diamond.png")
    w = Window(Dict(
        "webPreferences" => Dict("webSecurity" => false),  # to load local files
        "title" => "SpmImage Tycoon",
        "icon" => file_logo,
    ))
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

    @js_ w set_params($dir_asset, $auto_save_minutes)
    @js_ w set_last_directories($last_directories)
    @js_ w load_page()
    @js_ w show_start()

    set_event_handlers_basic(w)

    if dir_data != ""
        load_directory(abspath(dir_data), w)
    end
    
    # bring window to front
    @js w require("electron").remote.getCurrentWindow().show()
    return w
end

end