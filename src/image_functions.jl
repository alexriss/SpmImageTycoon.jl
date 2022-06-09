# initialize cache variable
memcache_images = ListNodeCache{SpmImage}(memcache_mb_images)
memcache_images_lock = ReentrantLock() 

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


"""calculates the histogram for the image specified by id.
Returns the bin width (normalized for bin positions between 0 and 1) and relative bin counts."""
function get_histogram(griditem::SpmGridItem, dir_data::String)::Tuple{Float32,Vector{Float32}}
    im_spm = load_image_memcache(joinpath(dir_data, griditem.filename_original))
    d = vec(get_image_data(griditem, im_spm, resize_to=resize_to, normalize=false, clamp=false)[1])

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
    return channel_name
end


"""Sets the next channel name for the griditem."""
function next_channel_name!(griditem::SpmGridItem, im_spm::SpmImage, jump::Int)::Nothing
    channel_name = griditem.channel_name    
    
    backward_suffix = ""
    if endswith(channel_name, " bwd")
        channel_name = channel_name[1:end-4]
        backward_suffix = " bwd"
    end
    i = findfirst(x -> x == channel_name, im_spm.channel_names)
    if i === nothing  # this should never happen anyways
        channel_name = im_spm.channel_names[1]
    else
        i = (i + jump - 1) % length(im_spm.channel_names) + length(im_spm.channel_names)
        i = i % length(im_spm.channel_names) + 1
        channel_name = im_spm.channel_names[i] * backward_suffix
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
    if endswith(griditem.channel_name, " bwd")
        channel_name = griditem.channel_name[1:end-4]
    else
        channel_name = griditem.channel_name * " bwd"
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


"""Get, resize, background correct and filter image data for a specific griditem. Returns a 2d array, the channel unit, minimum and maximum values."""
function get_image_data(griditem::SpmGridItem, im_spm::SpmImage; resize_to::Int=0, normalize::Bool=true, clamp::Bool=false)::Tuple{Array{Float32,2},String,Float32,Float32}
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
The "filename_display" field of the SpmGridItem is updated (to the png filename without the directory prefix)
if use_existing is true, then an updated image will only be generated if the last-modified date of the image does not correspon to the one save in the db."""
function create_image!(griditem::SpmGridItem, im_spm::SpmImage; resize_to::Int=0, base_dir::String="", use_existing::Bool=false)::Nothing
    if use_existing
        f = joinpath(base_dir, griditem.filename_display)
        if unix2datetime(mtime(f)) == griditem.filename_display_last_modified  # mtime will give 0 for files that do not exist (so we do not need to check if file exists)
            return nothing  # image exists, nothing to do
        end
    end

    # create grayscale image
    d, unit, vmin, vmax = get_image_data(griditem, im_spm, resize_to=resize_to, normalize=true, clamp=true)

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
    f = joinpath(base_dir, filename_display)
    save(f, im_arr)  # ImageIO should be installed, gives speed improvement for saving pngs

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
function set_range_selected!(ids::Vector{String}, dir_data::String, griditems::Dict{String,SpmGridItem}, range_selected::Array{Float64}, full_resolution::Bool)::Nothing
    dir_cache = get_dir_cache(dir_data)
    for id in ids  # we could use threads here as well, but so far we only do this for one image at once (and threads seem to make it a bit more unstable)
        filename_original = griditems[id].filename_original
        im_spm = load_image_memcache(joinpath(dir_data, filename_original))
        griditems[id].channel_range_selected = range_selected
        resize_to_ = full_resolution ? 0 : resize_to
        create_image!(griditems[id], im_spm, resize_to=resize_to_, base_dir=dir_cache)
    end
    return nothing
end


"""Reverts a spectrum to its default settings, returns `true` if anything was changed."""
function reset_default!(griditem::SpmGridItem, im_spm::SpmImage)::Bool
    channel_name= default_channel_name(im_spm)
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
    if griditem.filters != String[]
        griditem.filters = String[]
        changed = true
    end

    return changed
end


"""calcuates a line profile"""
function get_line_profile(id::String, dir_data::String, griditems::Dict{String,SpmGridItem}, start_point::Vector{Float64}, end_point::Vector{Float64}, width::Float64)::Tuple{Vector{Vector{Float64}}, Vector{Float64}, Vector{Union{Float64,Missing}}, Union{Float64,Missing}, Union{Float64,Missing}}
    filename_original = griditems[id].filename_original
    im_spm = load_image_memcache(joinpath(dir_data, filename_original))
    bg = background_correction_list_image[griditems[id].background_correction]
    coords, distances, values, start_point_value, end_point_value = line_profile(im_spm, griditems[id].channel_name, start_point, end_point, width, background=bg)

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
function parse_image!(griditems::Dict{String, SpmGridItem}, virtual_copies_dict::Dict{String,Array{SpmGridItem}},
    griditems_new::Vector{String}, only_new::Bool,
    dir_cache::String, datafile::String, id::String, filename_original::String,
    created::DateTime, last_modified::DateTime)::Vector{Task}

    tasks = Task[]

    im_spm = load_image(datafile, output_info=0)  # we dont use the cache here
    scan_direction = (im_spm.scan_direction == SpmImages.up) ? 1 : 0

    if haskey(griditems, id)
        griditem = griditems[id]
        # still update a few fields (the files may have changed) - but most of these fields should stay unchanged
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
        griditem.comment = utf8ify(im_spm.header["Comment"])
        griditem.status = 0
    else
        # get the respective image channel (depending on whether the feedback was on or not)
        channel_name = default_channel_name(im_spm)
        griditems[id] = SpmGridItem(
            id=id, type=SpmGridImage, filename_original=filename_original, created=created, last_modified=last_modified, recorded=im_spm.start_time,
            channel_name=channel_name, scansize=im_spm.scansize, scansize_unit=im_spm.scansize_unit,
            center=im_spm.center, angle=im_spm.angle, scan_direction=scan_direction,
            bias=im_spm.bias, z_feedback=im_spm.z_feedback, z_feedback_setpoint=im_spm.z_feedback_setpoint, z_feedback_setpoint_unit=im_spm.z_feedback_setpoint_unit, z=im_spm.z,
            colorscheme=default_color_scheme,
            comment=utf8ify(im_spm.header["Comment"])
        )
        if only_new
            push!(griditems_new, id)
        end
        griditem = griditems[id]
    end
    t = Threads.@spawn create_image!(griditem, im_spm, resize_to=resize_to, base_dir=dir_cache, use_existing=true)
    push!(tasks, t)
    
    # virtual copies
    if haskey(virtual_copies_dict, id)
        for virtual_copy in virtual_copies_dict[id]
            griditem = griditems[virtual_copy.id]
            # update fields here, too - however, most of these fields should stay unchanged
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
            griditem.comment = utf8ify(im_spm.header["Comment"])
            griditem.status = 0

            t = Threads.@spawn create_image!(griditem, im_spm, resize_to=resize_to, base_dir=dir_cache, use_existing=true)
            push!(tasks, t)
        end
    end
    return tasks
end