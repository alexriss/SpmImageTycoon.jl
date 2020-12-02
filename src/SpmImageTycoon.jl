__precompile__()

module SpmImageTycoon

using Blink
# export @js, @js_, @new, @var, AtomShell, Blink, Electron, Page, Window, active, body!, centre, closetools, content!, flashframe, floating, front, handle, id, importhtml!, js, load!, loadcss!, loadfile, loadhtml, loadjs!, loadurl, opentools, progress, resolve, shell, title, tools
using DataStructures
using Dates
using Images
using ImageIO
using JSON
using SpmImages
# import Blink.AtomShell: resolve_blink_asset

export SpmImageGridItem, tycoon

mutable struct SpmImageGridItem
    filename_original::String
    filename_display::String
    channel_name::String
    background_correction::String
end


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

resize_to = 256
extension_spm = ".sxm"

dir_cache_name = "_spmimages_cache"  # TODO: move this to user directory (and use unique folder names)
dir_res = "../res/"  # relative to module directory


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
function next_channel_name(image::SpmImage, current_channel_name::String)::String
    backward_suffix = ""
    if endswith(current_channel_name, " bwd")
        current_channel_name = current_channel_name[1:end-4]
        backward_suffix = " bwd"
    end
    current_index = findfirst(x -> x == current_channel_name, image.channel_names)
    if current_index === nothing  # this should never happen anyways
        return image.channel_names[1]
    else
        return image.channel_names[current_index % length(image.channel_names) + 1] * backward_suffix
    end
end


"""Gets the next background_correction key and value in the list of possible background corrections"""
function next_background_correction(background_correction::String)::String
    keys_bg = collect(keys(background_correction_list))
    i = findfirst(x -> x == background_correction, keys_bg)
    i = i % length(background_correction_list) + 1
    return keys_bg[i]
end


"""Creates and saves a png image from the specified channel_name in the image. If necessary, the image size is decreased to the specified size.
Returns the filename it created (without the directory prefix)"""
function create_image(image::SpmImage, filename_original::String, channel_name::String, background_correction::String; resize_to::Int=0, base_dir::String="")::String
    # create grayscale image
    d = get_channel(image, channel_name, origin="upper").data;
    d = correct_background(d, background_correction_list[background_correction])
    d_ = filter(!isnan,d)
    vmin, vmax = minimum(d_), maximum(d_)  # minimum and maximum function return NaN otherwise
    d = (d .- vmin) ./ (vmax - vmin)
    clamp01nan!(d)
    im_arr = Gray.(d)
    
    ratio = max(1, resize_to / max(image.pixelsize...))

    filename_display = filename_original[1:end-4] * "_$(channel_name)_$(background_correction).png"
    save(joinpath(base_dir, filename_display), imresize(im_arr, ratio=ratio))  # ImageIO should be installed, gives speed improvement for saving pngs
    # println(joinpath(dir_cache, fname))
    
    return filename_display
end


"""Loads the header data for an image and returns a dictionary with all the data"""
function get_image_info(id::Int, dir_data::String, images_parsed::Vector{SpmImageGridItem})::Tuple{Dict{String,String},OrderedDict{String,String}}
    filename_original = images_parsed[id].filename_original
    im_spm = load_image(joinpath(dir_data, filename_original), header_only=true, output_info=0)
    # extra data
    data_main = Dict(
        "filename" => filename_original[1:end-4],  # strip off extension
        "scansize" => join(im_spm.scansize, " x "),
        "scansize_unit" => im_spm.scansize_unit,
        "channel_name" => images_parsed[id].channel_name,
        "background_correction" => images_parsed[id].background_correction,
    )
    return data_main, im_spm.header
end


"""Cycles the channel or switches direction (backward/forward) for the images specified by ids. Modifies the images_parsed array and returns the new filenames and channel names."""
function switch_channel_direction_background!(ids::Vector{Int}, dir_data::String, images_parsed::Vector{SpmImageGridItem}, what::String)::Tuple{Vector{String}, Vector{String}, Vector{String}}
    dir_cache = get_dir_cache(dir_data)
    filenames = Vector{String}(undef, size(ids))
    channel_names = Vector{String}(undef, size(ids))
    background_corrections = Vector{String}(undef, size(ids))
    for (i, id) in enumerate(ids)
        filename_original = images_parsed[id].filename_original
        im_spm = load_image(joinpath(dir_data, filename_original), output_info=0)
        channel_name = images_parsed[id].channel_name
        background_correction = images_parsed[id].background_correction
        if what == "channel"
            channel_name = next_channel_name(im_spm, channel_name)
            images_parsed[id].channel_name = channel_name
        elseif what == "direction"
            if endswith(channel_name, " bwd")
                channel_name = channel_name[1:end-4]
            else
                channel_name = channel_name * " bwd"
            end
            images_parsed[id].channel_name = channel_name
        elseif what == "background_correction"
            background_correction = next_background_correction(background_correction)
            images_parsed[id].background_correction = background_correction
        end
        filename_display = create_image(im_spm, filename_original, channel_name, background_correction, resize_to=resize_to, base_dir=dir_cache)
        images_parsed[id].filename_display = filename_display
            
        filenames[i] = filename_display
        channel_names[i] = channel_name
        background_corrections[i] = background_correction
    end
    return filenames, channel_names, background_corrections
end


"""Parses files in a directory and creates the images for the default channels in a cache directory (which is a subdirectory of the data directory)"""
function parse_files(dir_data::String; output_info::Int=0)::Vector{SpmImageGridItem}
    dir_cache = get_dir_cache(dir_data)
    datafiles = filter!(x -> isfile(x) && endswith(x, extension_spm), readdir(dir_data, join=true))
    images_parsed = Vector{SpmImageGridItem}(undef, size(datafiles))
    time_start = Dates.now()
    for (i, datafile) in enumerate(datafiles)
        im_spm = load_image(datafile, output_info=0)
        
        # get the respective image channel (depending on whether the feedback was on or not)
        channel_name = default_channel_name(im_spm, channels_feedback, channels_no_feedback)
        
        filename_original = basename(datafile)
        filename_display = create_image(im_spm, filename_original, channel_name, "none", resize_to=resize_to, base_dir=dir_cache)
        
        images_parsed[i] = SpmImageGridItem(filename_original, filename_display, channel_name, "none")
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
    handle(w, "grid_item") do args  # cycle through scan channels
        # @show args
        what = args[1]
        ids_str = args[2]
        ids = [parse(Int64, id) for id in ids_str]
        if what == "next_channel"
            filenames, channel_names, background_corrections = switch_channel_direction_background!(ids, dir_data, images_parsed, "channel")
            @js_ w update_images($ids_str, $filenames, $channel_names, $background_corrections);
        elseif what == "next_direction"
            filenames, channel_names, background_corrections = switch_channel_direction_background!(ids, dir_data, images_parsed, "direction")
            @js_ w update_images($ids_str, $filenames, $channel_names, $background_corrections);
        elseif what == "next_background_correction"
            filenames, channel_names, background_corrections = switch_channel_direction_background!(ids, dir_data, images_parsed, "background_correction")
            @js_ w update_images($ids_str, $filenames, $channel_names, $background_corrections);
        elseif what == "get_info"
            id = ids[1]

            # get header data
            image_info_main, image_info_header = get_image_info(id, dir_data, images_parsed)
            k = replace.(collect(keys(image_info_header)), ">" => "><wbr>")[3:end]  # replace for for word wrap in tables
            v = replace.(collect(values(image_info_header)), "\n" => "<br />")[3:end]  # the first two rows are not useful to display, so cut them off
            image_info_header_json = JSON.json(vcat(reshape(k, 1, :), reshape(v, 1, :)))

             @js_ w show_info($id, $image_info_main, $image_info_header_json);
        end
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

    @js w set_base_href($dir_asset)
    @js w set_dir_cache($dir_cache_js)
    @js w load_page()
    
    ids = collect(1:length(images_parsed))
    filenames = [s.filename_display for s in images_parsed]
    filenames_original = [s.filename_original for s in images_parsed]
    channel_names = [s.channel_name for s in images_parsed]
    background_corrections = [s.channel_name for s in images_parsed]
    @js_ w load_images($ids, $filenames, $filenames_original, $channel_names, $background_corrections)

    set_event_handlers(w, dir_data, images_parsed)

    # bring window to front
    @js w require("electron").remote.getCurrentWindow().show()
    return w
end

end
