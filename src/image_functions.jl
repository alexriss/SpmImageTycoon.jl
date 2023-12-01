# initialize cache variable
memcache_images = ListNodeCache{SpmImage}(memcache_mb_images)
memcache_images_lock = ReentrantLock() 
memcache_imagedata = ListNodeCache{Tuple{Array{Float32,2},String}}(memcache_mb_imagedata)
memcache_imagedata_lock = ReentrantLock() 


"""channel name for forward direction"""
function image_channel_name_fwd(name)
    if endswith(name, " bwd")
        name = name[1:end-4]
    end
    return name
end

"""channel name for backward direction"""
function image_channel_name_bwd(name)
    if !endswith(name, " bwd")
        name *= " bwd"
    end
    return name
end

"""returns if the name ccorresponds to the forward direction"""
function is_image_channel_name_fwd(name)
    return !endswith(name, " bwd")
end


"""saves all colorbars as pngs in the cache directory.
Returns a dictionary that associates each colorscheme name with a png file"""
function save_colorbars(dict_colorschemes::OrderedDict{String,ColorScheme}, dir_data::String, width::Int=512, height::Int=20)::OrderedDict{String,String}
    dir_cache = get_dir_cache(dir_data)
    res = OrderedDict{String,String}()
    for (k,v) in dict_colorschemes
        m = repeat(transpose(collect(0:1/(width-1):1)), inner=(height,1))
        img = get(v, m)
        fname = k * ".png"
        save(joinpath(dir_cache, dir_colorbars, fname), img)      # you'll need FileIO or similar to do this
        res[k] = fname
    end

    return res
end


"""calculates the histogram for the image specified by id.
Returns the bin width (normalized for bin positions between 0 and 1) and relative bin counts."""
function get_histogram(griditem::SpmGridItem, dir_data::String)::Tuple{Float32,Vector{Float32}}
    im_spm = load_image_memcache(joinpath(dir_data, griditem.filename_original))
    dir_cache = get_dir_cache(dir_data)
    d = vec(get_image_data_cache(griditem, im_spm, resize_to=resize_to, dir_cache=dir_cache, cache_safe=true, normalize=false, clamp=false)[1])

    filter!(!isnan, d)
    N = length(d)
    if N == 0
        return 0, []
    end
    normalize01!(d)  # we normalize here, otherwise the hist generation does not seem to be robust
    # clamp01nan!(d)
    # nbins = min(ceil(Int, sqrt(N)), 256)
    nbins = 256
    hist = StatsBase.fit(StatsBase.Histogram, d, nbins=nbins)  # the function will give "approximate" number of bins

    counts = hist.weights ./ maximum(hist.weights)
    # normalize width so that the bin-positions are between 0 and 1
    hist_range = hist.edges[1]  # 1 because it gives out a tuple
    width = step(hist_range)

    return width, counts
end


"""gets the default channel name (according to the lists image_channels_feedback_on and image_channels_feedback_off in config.jl) and the z-feedback status of im_spm."""
function default_channel_name(im_spm::SpmImage)::String
    channel_name = ""
    if im_spm.z_feedback
        channels = image_channels_feedback_on
    else
        channels = image_channels_feedback_off
    end
    for c in channels
        if c in im_spm.channel_names
            channel_name = c
            break
        end
    end
    if channel_name == ""
        channel_name = im_spm.channel_names[1]
    end
    # use backwards channel if it exists and forward channel does not exist
    i_channel_name = findfirst(isequal(channel_name), im_spm.channel_names)
    if im_spm.channel_indices_fwd[i_channel_name] == 0 && im_spm.channel_indices_bwd[i_channel_name] != 0
        channel_name = image_channel_name_bwd(channel_name)
    end
    return channel_name
end


"""Sets the next channel name for the griditem."""
function next_channel_name!(griditem::SpmGridItem, im_spm::SpmImage, jump::Int)::Nothing
    channel_name = griditem.channel_name    
    
    channel_names = sort_channel_names(im_spm.channel_names)
    bwd = !is_image_channel_name_fwd(channel_name)
    if bwd
        channel_name = image_channel_name_fwd(channel_name)
    end

    i = findfirst(x -> x == channel_name, channel_names)
    if i === nothing  # this should never happen anyways
        channel_name = channel_names[1]
    else
        i = (i + jump - 1) % length(channel_names) + length(channel_names)
        i = i % length(channel_names) + 1
        channel_name = channel_names[i]
    end
    if bwd
        channel_name = image_channel_name_bwd(channel_name)
    end

    griditem.channel_name = channel_name
    griditem.channel_range_selected = [] # reset selected range when switching channel (we try to keep it for all other cases for now)
    return nothing
end


"""Sets the next channel2 name for the griditem, dummy function for images."""
function next_channel2_name!(griditem::SpmGridItem, im_spm::SpmImage, jump::Int)::Nothing
    return nothing
end


# toggles between forwards and backward scan
function next_direction!(griditem::SpmGridItem, im_spm::SpmImage)::Nothing
    if is_image_channel_name_fwd(griditem.channel_name)
        channel_name = image_channel_name_bwd(griditem.channel_name)
    else
        channel_name = image_channel_name_fwd(griditem.channel_name)
    end
    griditem.channel_name = channel_name

    return nothing
end


"""Sets the next background_correction key in the list of possible background corrections"""
function next_background_correction!(griditem::SpmGridItem, im_spm::SpmImage, jump::Int)::Nothing
    keys_bg = collect(keys(background_correction_list_image))
    i = findfirst(x -> x == griditem.background_correction, keys_bg)
    i = (i + jump - 1) % length(background_correction_list_image) + length(background_correction_list_image)
    i = i % length(background_correction_list_image) + 1
    griditem.background_correction = keys_bg[i]
    return nothing
end


"""Sets the next colorscheme key in the list of possible colorschemes"""
function next_colorscheme!(griditem::SpmGridItem, im_spm::SpmImage, jump::Int)::Nothing
    keys_cs = collect(keys(colorscheme_list))
    i = findfirst(x -> x == griditem.colorscheme, keys_cs)
    i = (i + sign(jump) + jump - 1) % length(colorscheme_list) + length(colorscheme_list)   # inverted and normal are alternating, so an extra +1 or -1 (i.e. sign(jump) is needed
    i = i % length(colorscheme_list) + 1
    griditem.colorscheme = keys_cs[i]
    return nothing
end


"""Sets the inverted colorscheme key in the list of possible colorschemes"""
function next_invert!(griditem::SpmGridItem, im_spm::SpmImage)::Nothing
    if endswith(griditem.colorscheme, " inv")
        griditem.colorscheme = griditem.colorscheme[1:end-4]
    else
        griditem.colorscheme = griditem.colorscheme * " inv"
    end
    return nothing
end


"""gives a colorscheme to an 2D grayscale image (i.e. and image with values between 0 and 1)"""
function colorize(data::Array{<:Number,2}, colorscheme::String)::Array{RGB{Float32},2}
    m, n = size(data)
    cs = colorscheme_list[colorscheme]
    res = Array{RGB{Float32}}(undef, m, n)
    for j in 1:n, i in 1:m
        @views @inbounds res[i,j] = getindex(cs, round(Int, data[i,j] * (length(cs) - 1)) + 1)
    end
    return res
end


"""Gets the image data from cache (if it exists, otherwise calls the function `get_image_data`)"""
function get_image_data_cache(griditem::SpmGridItem, im_spm::SpmImage;
    resize_to::Int=0, dir_cache::String="", cache_safe::Bool=true, normalize::Bool=true, clamp::Bool=false)::Tuple{Array{Float32,2},String,Float32,Float32}
    res = missing
    usecache = true
    key = griditem.id * "_" * griditem.channel_name * "_" * griditem.background_correction * "_" * string(griditem.edits) * "_" * string(resize_to)
    
    if !cache_safe  # this occurs when there are edits in the image - some edits have to generate images (such as the FT filter)
        for notallowed in memcache_disable_imagedata
            if contains(key, notallowed)
                usecache = false
                break
            end
        end
    end
    lock(memcache_imagedata_lock) do
        usecache && (res = get_cache(memcache_imagedata, key))
        if ismissing(res)
            res = get_image_data(griditem, im_spm; dir_cache=dir_cache, resize_to=resize_to)
            set_cache(memcache_imagedata, key, res)
        end
    end

    d = deepcopy(res[1])
    if normalize
        vmin, vmax = normalize01!(d, range_selected=griditem.channel_range_selected)  # normalize each value in the array to values between 0 and 1
    else
        vmin, vmax = 0f0, 0f0  # we only need it when also normalizing it
    end
    if clamp
        clamp01nan!(d)
    end

    return d, res[2], vmin, vmax
end


"""Get, resize, background correct and filter image data for a specific griditem. Returns a 2d array, the channel unit, minimum and maximum values."""
function get_image_data(griditem::SpmGridItem, im_spm::SpmImage; dir_cache::String="", resize_to::Int=0)::Tuple{Array{Float32,2},String}
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

    d = SpmImages.correct_background(d, background_correction_list_image[griditem.background_correction])
    apply_edits!(griditem, d, dir_cache=dir_cache)

    return d, unit
end


"""Creates and saves a png image from the specified channel_name in the image. If necessary, the image size is decreased to the specified size.
The "filename_display" field of the SpmGridItem is updated (to the png filename without the directory prefix)
if use_existing is true, then an updated image will only be generated if the last-modified date of the image does not correspon to the one save in the db."""
function create_image!(griditem::SpmGridItem, im_spm::SpmImage; resize_to::Int=0, dir_cache::String="", cache_safe::Bool=true, use_existing::Bool=false)::Nothing
    if use_existing
        f = joinpath(dir_cache, griditem.filename_display)
        if unix2datetime(mtime(f)) == griditem.filename_display_last_modified  # mtime will give 0 for files that do not exist (so we do not need to check if file exists)
            return nothing  # image exists, nothing to do
        end
    end

    # create grayscale image
    d, unit, vmin, vmax = get_image_data_cache(griditem, im_spm, resize_to=resize_to, dir_cache=dir_cache, cache_safe=cache_safe, normalize=true, clamp=true)

    if griditem.colorscheme == "gray"  # special case, we dont need the actual colorscheme
        im_arr = Gray.(d)
    else
        im_arr = colorize(d, griditem.colorscheme)
    end
    
    if griditem.filename_display === ""
        filename_display = get_filename_display(griditem)
    else
        filename_display = griditem.filename_display
    end
    f = joinpath(dir_cache, filename_display)
    try
        save(f, im_arr)  # ImageIO should be installed, gives speed improvement for saving pngs
    catch e
        if isa(e, SystemError) || isa(e, Base.IOError)
            f = joinpath(get_dir_temp_cache_cache(dir_cache), filename_display)
            save(f, im_arr)
            griditem.status = 10
        else
            rethrow(e)
        end
    end

    lock(griditems_lock) do
        griditem.channel_unit = unit
        griditem.channel_range = [vmin, vmax]
        if griditem.filename_display === ""
            griditem.filename_display = filename_display
        end
        griditem.filename_display_last_modified = unix2datetime(mtime(f))
    end

    return nothing
end


"""sets selected range and recreates images"""
function set_range_selected!(ids::Vector{String}, dir_data::String, griditems::Dict{String,SpmGridItem}, range_selected::Vector{Float64}, full_resolution::Bool)::Nothing
    dir_cache = get_dir_cache(dir_data)
    for id in ids  # we could use threads here as well, but so far we only do this for one image at once (and threads seem to make it a bit more unstable)
        filename_original = griditems[id].filename_original
        im_spm = load_image_memcache(joinpath(dir_data, filename_original))
        griditems[id].channel_range_selected = range_selected
        resize_to_ = full_resolution ? 0 : resize_to
        create_image!(griditems[id], im_spm, resize_to=resize_to_, dir_cache=dir_cache)
    end
    return nothing
end


"""Reverts a spectrum to its default settings, returns `true` if anything was changed."""
function reset_default!(griditem::SpmGridItem, im_spm::SpmImage)::Bool
    # we need all channel names to change GSXM files
    is_gsxm_image(griditem) && (im_spm.channel_names = get_gsxm_channel_names(griditem))
    channel_name = default_channel_name(im_spm)
    change_gsxm_griditem_filename_original!(griditem, channel_name)

    if griditem.channel_name != channel_name
        griditem.channel_name = channel_name
        # unit will be set in the create_image! function
        changed = true
    end
    if griditem.background_correction != "none"
        griditem.background_correction = "none"
        changed = true
    end
    if griditem.colorscheme != default_color_scheme
        griditem.colorscheme = default_color_scheme
        changed = true
    end
    if griditem.channel_range_selected != [0, 1] || length(griditem.channel_range_selected) != 0
        griditem.channel_range_selected = Float64[]
        changed = true
    end
    if griditem.edits != String[]
        griditem.edits = String[]
        changed = true
    end

    return changed
end


"""calculates a line profile"""
function get_line_profile(id::String, dir_data::String, griditems::Dict{String,SpmGridItem}, start_point::Vector{Float64}, end_point::Vector{Float64}, width::Float64)::Tuple{Vector{Vector{Float64}}, Vector{Float64}, Vector{Union{Float64,Missing}}, Union{Float64,Missing}, Union{Float64,Missing}}
    griditem = griditems[id]
    filename_original = griditem.filename_original
    im_spm = load_image_memcache(joinpath(dir_data, filename_original))
    dir_cache = get_dir_cache(dir_data)
    data, unit, vmin, vmax = get_image_data_cache(griditem, im_spm, resize_to=resize_to, dir_cache=dir_cache, cache_safe=true, normalize=false, clamp=false)
    coords, distances, values, start_point_value, end_point_value = line_profile(im_spm, data, start_point, end_point, width, origin="upper")

    return coords, distances, values, start_point_value, end_point_value
end


"""
    function load_image_memcache(filename::AbstractString)::SpmImage

Loads an image from either the file or the memory cache.
"""
function load_image_memcache(filename::AbstractString)::SpmImage
    im_spm = missing
    lock(memcache_images_lock) do
        im_spm = get_cache(memcache_images, filename)
        if im_spm === missing
            im_spm = load_image(filename, output_info=0)
            set_cache(memcache_images, filename, im_spm)
        end
    end

    return im_spm
end


"""Parses an image file and creates the images in the cache directory if necessary."""
function parse_image!(griditems::Dict{String, SpmGridItem}, virtual_copies_dict::Dict{String,Vector{SpmGridItem}},
    griditems_new::Vector{String}, channel_names_list::Dict{String,Vector{String}}, only_new::Bool, use_existing::Bool,
    dir_cache::String, datafiles::Vector{String}, id::String,
    created::DateTime, last_modified::DateTime)::Tuple{Vector{Task},String}

    tasks = Task[]
    im_spm = missing
    try
        im_spm = load_image(datafiles, output_info=0)  # we dont use the cache here
    catch e
        err = basename(datafiles[1]) * ": " * e.msg
        return tasks, err
    end
    scan_direction = (im_spm.scan_direction == SpmImages.up) ? 1 : 0
    filename_original = basename(datafiles[1])

    if haskey(griditems, id)
        griditem = griditems[id]
        # still update a few fields (the files may have changed) - but most of these fields should stay unchanged
        if length(datafiles) > 1
            if haskey(channel_names_files[id], griditem.channel_name)
                filename_original = channel_names_files[id][griditem.channel_name]
            else
                filename_original = channel_names_files[id][default_channel_name(im_spm)]
            end
        end
        griditem.type = SpmGridImage
        griditem.filename_original = filename_original
        griditem.created = created
        griditem.last_modified = last_modified
        griditem.recorded = im_spm.start_time
        griditem.scansize = im_spm.scansize
        griditem.scansize_unit = im_spm.scansize_unit
        griditem.center = im_spm.center
        griditem.angle = im_spm.angle
        griditem.scan_direction = scan_direction
        griditem.bias = im_spm.bias
        griditem.z_feedback = im_spm.z_feedback
        griditem.z_feedback_setpoint = im_spm.z_feedback_setpoint
        griditem.z_feedback_setpoint_unit = im_spm.z_feedback_setpoint_unit
        griditem.z = im_spm.z
        griditem.comment = haskey(im_spm.header, "Comment") ? utf8ify(im_spm.header["Comment"]) : ""
        griditem.status = 0
    else
        # get the respective image channel (depending on whether the feedback was on or not)
        channel_name = default_channel_name(im_spm)
        length(datafiles) > 1 && (filename_original = channel_names_files[id][channel_name])
        comment = haskey(im_spm.header, "Comment") ? utf8ify(im_spm.header["Comment"]) : ""
        griditems[id] = SpmGridItem(
            id=id, type=SpmGridImage, filename_original=filename_original, created=created, last_modified=last_modified, recorded=im_spm.start_time,
            channel_name=channel_name, scansize=im_spm.scansize, scansize_unit=im_spm.scansize_unit,
            center=im_spm.center, angle=im_spm.angle, scan_direction=scan_direction,
            bias=im_spm.bias, z_feedback=im_spm.z_feedback, z_feedback_setpoint=im_spm.z_feedback_setpoint, z_feedback_setpoint_unit=im_spm.z_feedback_setpoint_unit, z=im_spm.z,
            colorscheme=default_color_scheme,
            comment=comment
        )
        if only_new
            push!(griditems_new, id)
        end
        griditem = griditems[id]
    end
    channel_names_list[base_filename(filename_original)] = im_spm.channel_names
    t = Threads.@spawn create_image!(griditem, im_spm, resize_to=resize_to, dir_cache=dir_cache, use_existing=use_existing)
    push!(tasks, t)
    
    # virtual copies
    if haskey(virtual_copies_dict, id)
        if length(datafiles) > 1
            if haskey(channel_names_files[id], virtual_copy.channel_name)
                filename_original = channel_names_files[id][virtual_copy.channel_name]
            else
                filename_original = channel_names_files[id][default_channel_name(im_spm)]
            end
        end
        for virtual_copy in virtual_copies_dict[id]
            # update fields here, too - however, most of these fields should stay unchanged
            virtual_copy.type = SpmGridImage
            virtual_copy.filename_original = filename_original
            virtual_copy.created = created
            virtual_copy.last_modified = last_modified
            virtual_copy.recorded = im_spm.start_time
            virtual_copy.scansize = im_spm.scansize
            virtual_copy.scansize_unit = im_spm.scansize_unit
            virtual_copy.center = im_spm.center
            virtual_copy.angle = im_spm.angle
            virtual_copy.scan_direction = scan_direction
            virtual_copy.bias = im_spm.bias
            virtual_copy.z_feedback = im_spm.z_feedback
            virtual_copy.z_feedback_setpoint = im_spm.z_feedback_setpoint
            virtual_copy.z_feedback_setpoint_unit = im_spm.z_feedback_setpoint_unit
            virtual_copy.z = im_spm.z
            virtual_copy.comment = haskey(im_spm.header, "Comment") ? utf8ify(im_spm.header["Comment"]) : ""
            virtual_copy.status = 0

            t = Threads.@spawn create_image!(virtual_copy, im_spm, resize_to=resize_to, dir_cache=dir_cache, use_existing=use_existing)
            push!(tasks, t)
        end
    end
    return tasks, ""
end