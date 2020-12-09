__precompile__()

module SpmImageTycoon

using Blink
using ColorSchemes
using DataStructures
using Dates
using Images
using ImageIO
using JSON
using SpmImages
# import Blink.AtomShell: resolve_blink_asset

export SpmImageGridItem, tycoon

mutable struct SpmImageGridItem
    filename_original::String        # original filename (.sxm)
    filename_display::String         # generated png image
    channel_name::String             # channel name (" bwd" indicates backward direction)
    scansize::Vector{Float64}        # scan size in physical units
    scansize_unit::String            # scan size unit
    background_correction::String    # type of background correction used
    filters::Vector{String}          # array of filters used (not implemented yet)
    colorscheme::String              # color scheme
    rating::Int                      # rating (0 to 5 stars)
    keywords::Vector{String}         # keywords
end
SpmImageGridItem(
    filename_original, filename_display, channel_name, scansize, scansize_unit
) = SpmImageGridItem(
    filename_original, filename_display, channel_name, scansize, scansize_unit, "none", [], "gray", 0, []
)


# default settings (should be overriden by config file later)
channels_feedback = ["Z"]
channels_no_feedback = ["Frequency Shift", "Current"]

background_correction_list = OrderedDict{String,Background}(
    "none" => no_correction,
    "plane" => plane_linear_fit,
    "line average" => line_average,
    "vline average" => vline_average,
    "line linear" => line_linear_fit,
    "vline linear" => vline_linear_fit,
)

colorscheme_list_pre = OrderedDict{String,ColorScheme}(
    "gray" => ColorSchemes.grays,  # we wont use this, though, will just be the standard Gray-function
    "thermal" => ColorSchemes.thermal,
    "ice" => ColorSchemes.ice,
    "batlow" => ColorSchemes.batlow,
    "davos" => ColorSchemes.davos,
    "hawaii" => ColorSchemes.hawaii,
    "imola" => ColorSchemes.imola,
    "lapaz" => ColorSchemes.lapaz,
    "oslo" => ColorSchemes.oslo,
    "tokyo" => ColorSchemes.tokyo,
    "copper" => ColorSchemes.copper,
    "inferno" => ColorSchemes.inferno,
    "CMRmap" => ColorSchemes.CMRmap,
    "avocado" => ColorSchemes.avocado,
    "rainbow" => ColorSchemes.rainbow,
    "rust" => ColorSchemes.rust,
    "valentine" => ColorSchemes.valentine,
    "fuchsia" => ColorSchemes.fuchsia,
    "deepsea" => ColorSchemes.deepsea
)
colorscheme_list = OrderedDict{String,ColorScheme}()  # will be populated by "colorscheme_list_to_256!"


resize_to = 2048  # we set it very high, so probably no images will be resized. A smaller value might improve performance (or not)
extension_spm = ".sxm"

dir_cache_name = "_spmimages_cache"  # TODO: move this to user directory (and use unique folder names)
dir_res = "../res/"  # relative to module directory



"""converts all the colorschemes in dict_colorschemes_pre to 256-step colorschemes (this will help performance), also generates inverse schemes.
The resulting schemes are stored in the OrderedDict dict_colorschemes."""
function colorscheme_list_to_256!(dict_colorschemes::OrderedDict{String,ColorScheme}, dict_colorschemes_pre::OrderedDict{String,ColorScheme})
    for (k,v) in dict_colorschemes_pre
        dict_colorschemes[k] = loadcolorscheme(
            Symbol(k * "_256"),
            [get(v, i) for i in 0.0:1/255:1.0],
            getfield(v, :category),
            getfield(v, :notes)
        )

        # inverted color scheme
        dict_colorschemes[k * " inv"] = loadcolorscheme(
            Symbol(k * "_inv_256"),
            [get(v, i) for i in 1.0:-1/255:0.0],
            getfield(v, :category),
            getfield(v, :notes)
        )
    end
end


"""adds a trailing slash to a directory if necessary"""
function add_trailing_slash(directory::String)::String
    return joinpath(directory, "")
    # if directory[end] in ['/', '\\'] 
    #     return directory
    # else
    #     return directory * "/"
    # end
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


"""gets the default channel name (according to the lists channels_feedback and channels_nofeedback) and the z-feedback status of image."""
function default_channel_name(image::SpmImage, channels_feedback::Vector{String}, channels_no_feedback::Vector{String})::String
    channel_name = ""
    if image.z_feedback
        channels = channels_feedback
    else
        channels = channels_no_feedback
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


"""Creates and saves a png image from the specified channel_name in the image. If necessary, the image size is decreased to the specified size.
Returns the filename it created (without the directory prefix)"""
function create_image(image::SpmImage, filename_original::String, channel_name::String, background_correction::String; resize_to::Int=0, colorscheme::String="gray", base_dir::String="")::String
    # create grayscale image
    d = get_channel(image, channel_name, origin="upper").data;

    ratio = min(1, resize_to / max(image.pixelsize...))
    if ratio <= 0.0
        ratio = 1
    end
    if ratio < 1
        d = imresize(d, ratio=ratio)
    end

    d = correct_background(d, background_correction_list[background_correction])
    d_ = filter(!isnan,d)
    vmin, vmax = minimum(d_), maximum(d_)  # minimum and maximum function return NaN otherwise
    d = (d .- vmin) ./ (vmax - vmin)
    clamp01nan!(d)

    if colorscheme == "gray"  # special case, we dont need the actual colorscheme
        im_arr = Gray.(d)
    else
        im_arr = colorize(d, colorscheme)
    end
    

    filename_display = filename_original[1:end-4] * "_$(channel_name)_$(background_correction)_$(colorscheme).png"
    save(joinpath(base_dir, filename_display), im_arr)  # ImageIO should be installed, gives speed improvement for saving pngs
    # println(joinpath(dir_cache, fname))
    
    return filename_display
end


"""Loads the header data for an image and returns a dictionary with all the data"""
function get_image_header(id::Int, dir_data::String, images_parsed::Vector{SpmImageGridItem})::OrderedDict{String,String}
    filename_original = images_parsed[id].filename_original
    im_spm = load_image(joinpath(dir_data, filename_original), header_only=true, output_info=0)
    return im_spm.header
end


"""Cycles the channel, switches direction (backward/forward), changes background correction, changes colorscheme, or inverts colorscheme
for the images specified by ids. The type of change is specified by the argument "what".
The argument "jump" specifies whether to cycle backward or forward (if applicable).
The argument "full_resolution" specifies whether the images will be served in full resolution or resized to a smaller size.
Modifies the images_parsed array."""
function switch_channel_direction_background!(ids::Vector{Int}, dir_data::String, images_parsed::Vector{SpmImageGridItem}, what::String, jump::Int, full_resolution::Bool)
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
        filename_display = create_image(im_spm, filename_original, channel_name,
            background_correction, resize_to=resize_to_, colorscheme=images_parsed[id].colorscheme, base_dir=dir_cache)
        images_parsed[id].filename_display = filename_display
    end
    return nothing
end


"""Parses files in a directory and creates the images for the default channels in a cache directory (which is a subdirectory of the data directory)"""
function parse_files(dir_data::String; output_info::Int=0)::Vector{SpmImageGridItem}
    dir_cache = get_dir_cache(dir_data)
    datafiles = filter!(x -> isfile(x) && endswith(x, extension_spm), readdir(dir_data, join=true))
    images_parsed = Vector{SpmImageGridItem}(undef, size(datafiles))
    time_start = Dates.now()
    Threads.@threads for (i, datafile) in collect(enumerate(datafiles))  # the "collect" is needed for the threads macro
        im_spm = load_image(datafile, output_info=0)
        
        # get the respective image channel (depending on whether the feedback was on or not)
        channel_name = default_channel_name(im_spm, channels_feedback, channels_no_feedback)
        
        filename_original = basename(datafile)
        filename_display = create_image(im_spm, filename_original, channel_name, "none", resize_to=resize_to, base_dir=dir_cache)
        
        images_parsed[i] = SpmImageGridItem(filename_original, filename_display, channel_name, im_spm.scansize, im_spm.scansize_unit)
    end

    elapsed_time = Dates.now() - time_start
    if output_info > 0
        println("Parsed $(length(images_parsed)) files in $elapsed_time.")
    end
    return images_parsed
end


"""sets the julia handlers that are triggered by javascript events"""
function set_event_handlers(w::Window, dir_data::String, images_parsed::Vector{SpmImageGridItem})
    # change channel
    l = ReentrantLock()  # not sure if it is necessary to do it here, but it shoul be safer this way
    handle(w, "grid_item") do args  # cycle through scan channels
        # @show args
        what = args[1]
        ids_str = args[2]
        ids = [parse(Int64, id) for id in ids_str]
        if what == "get_info"
            id = ids[1]
            # get header data
            image_header = get_image_header(id, dir_data, images_parsed)
            k = replace.(collect(keys(image_header)), ">" => "><wbr>")[3:end]  # replace for for word wrap in tables
            v = replace.(collect(values(image_header)), "\n" => "<br />")[3:end]  # the first two rows are not useful to display, so cut them off
            image_header_json = JSON.json(vcat(reshape(k, 1, :), reshape(v, 1, :)))
            @js_ w show_info($id, $image_header_json);
        elseif what[1:5] == "next_"
            lock(l)
            jump = args[3]
            full_resolution = args[4]
            try
                switch_channel_direction_background!(ids, dir_data, images_parsed, what[6:end], jump, full_resolution)
                @js_ w update_images($ids_str, $(images_parsed[ids]));
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
                    @js_ w update_images($ids_str, $(images_parsed[ids]));
                finally
                    unlock(l)
                end
            elseif what[5:end] == "keywords"
                lock(l)
                keywords = args[3]
                println(keywords)
                try
                    for id in ids
                        images_parsed[id].keywords = keywords
                    end
                    @js_ w update_images($ids_str, $(images_parsed[ids]));
                finally
                    unlock(l)
                end
            end
        end
    end

    handle(w, "re_parse_images") do args
        lock(l)
        try
            images_parsed = parse_files(dir_data)
            ids = collect(1:length(images_parsed))
            @js_ w load_images($ids, $images_parsed, true)
        finally
            unlock(l)
        end
    end

    handle(w, "debug") do args
        println("debug: " * string(args))
    end

    return nothing
end


"""Start the main GUI and loads images from dir_data"""
function tycoon(dir_data::String; w::Union{Window,Nothing}=nothing)::Window
    if w === nothing
        file_logo = path_asset("logo_diamond.png")
        w = Window(Dict(
            "webPreferences" => Dict("webSecurity" => false),  # to load local files
            "title" => "SpmImage Tycoon",
            "icon" => file_logo,
        ))
        @js w require("electron").remote.getCurrentWindow().setIcon($file_logo)
        @js w require("electron").remote.getCurrentWindow().maximize()
    end

    colorscheme_list_to_256!(colorscheme_list, colorscheme_list_pre)  # so we have 256 steps in each colorscheme - also automatically create the inverted colorschemes

    images_parsed = parse_files(dir_data)  # TODO: parse and display image one by one

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

    # call js functions to setup everything
    dir_cache = get_dir_cache(dir_data)
    dir_cache_js = add_trailing_slash(dir_cache)

    @js_ w set_base_href($dir_asset)
    @js_ w set_dir_cache($dir_cache_js)
    @js_ w load_page()
    
    ids = collect(1:length(images_parsed))
    @js_ w load_images($ids, $images_parsed)

    set_event_handlers(w, dir_data, images_parsed)

    # bring window to front
    @js w require("electron").remote.getCurrentWindow().show()
    return w
end

end
