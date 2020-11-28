module SpmImageTycoon

using Blink
# export @js, @js_, @new, @var, AtomShell, Blink, Electron, Page, Window, active, body!, centre, closetools, content!, flashframe, floating, front, handle, id, importhtml!, js, load!, loadcss!, loadfile, loadhtml, loadjs!, loadurl, opentools, progress, resolve, shell, title, tools
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
end


# default settings (should be overriden by config file later)
channels_feedback = ["Z"]
channels_no_feedback = ["Frequency_Shift", "Current"]

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
    current_index = findfirst(x -> x == current_channel_name, image.channel_names)
    if current_index == nothing
        return image.channel_names[1]
    else
        return image.channel_names[current_index % length(image.channel_names) + 1]
    end
end


"""Creates and saves a png image from the specified channel_name in the image. If necessary, the image size is decreased to the specified size.
Returns the filename it created (without the directory prefix)"""
function create_image(image::SpmImage, filename_original::String, channel_name::String; resize_to::Int=0, base_dir::String="")::String
    # create grayscale image
    d = get_channel(image, channel_name, origin="upper").data;
    vmin, vmax = minimum(d), maximum(d)
    d = (d .- vmin) ./ (vmax - vmin)
    clamp01nan!(d)
    im_arr = Gray.(d)
    
    ratio = max(1, resize_to / max(image.pixelsize...))

    filename_display = filename_original[1:end-4] * "_$channel_name.png"
    save(joinpath(base_dir, filename_display), imresize(im_arr, ratio=ratio))  # ImageIO should be installed, gives speed improvement for saving pngs
    # println(joinpath(dir_cache, fname))
    
    return filename_display
end


"""Cycles the channel or switches direction (backward/forward) for the images specified by ids. Modifies the images_parsed array and returns the new filenames."""
function switch_channel_direction!(ids::Vector{Int}, dir_data::String, images_parsed::Vector{SpmImageGridItem}, what::String)::Vector{String}
    dir_cache = get_dir_cache(dir_data)
    filenames = Vector{String}()
    for id in ids
        filename_original = images_parsed[id].filename_original
        im_spm = load_image(joinpath(dir_data, filename_original), output_info=0)
        channel_name = images_parsed[id].channel_name
        if what == "channel"
            channel_name = next_channel_name(im_spm, channel_name)
        elseif what == "direction"
            if endswith(channel_name, "_bwd")
                channel_name = channel_name[1:end-4]
            else
                channel_name = channel_name * "_bwd"
            end
        end
        filename_display = create_image(im_spm, filename_original, channel_name, resize_to=resize_to, base_dir=dir_cache)

        # updated images_parsed
        images_parsed[id].channel_name = channel_name
        images_parsed[id].filename_display = filename_display
            
        push!(filenames, filename_display)
    end
    return filenames
end


"""Parses files in a directory and creates the images for the default channels in a cache directory (which is a subdirectory of the data directory)"""
function parse_files(dir_data::String; output_info::Int=0)::Vector{SpmImageGridItem}
    dir_cache = get_dir_cache(dir_data)
    datafiles = filter!(x -> isfile(x) && endswith(x, extension_spm), readdir(dir_data, join=true))
    images_parsed = Vector{SpmImageGridItem}()
    time_start = Dates.now()
    for datafile in datafiles
        im_spm = load_image(datafile, output_info=0)
        
        # get the respective image channel (depending on whether the feedback was on or not)
        channel_name = default_channel_name(im_spm, channels_feedback, channels_no_feedback)
        
        filename_original = basename(datafile)
        filename_display = create_image(im_spm, filename_original, channel_name, resize_to=resize_to, base_dir=dir_cache)
        
        push!(images_parsed, SpmImageGridItem(filename_original, filename_display, channel_name))
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
    handle(w, "next_channel") do args...  # cycle through scan channels
        # @show args
        ids_str = args[1]
        ids = [parse(Int64, id) for id in ids_str]
        filenames = switch_channel_direction!(ids, dir_data, images_parsed, "channel")
        @js_ w update_images($ids_str, $filenames);
    end

    handle(w, "next_direction") do args...  # switch between forward and backward channels
        # @show args
        ids_str = args[1]
        ids = [parse(Int64, id) for id in ids_str]
        filenames = switch_channel_direction!(ids, dir_data, images_parsed, "direction")
        @js_ w update_images($ids_str, $filenames);
    end

    return nothing
end


"""Start the main GUI and loads images from dir_data"""
function tycoon(dir_data::String; w::Union{Window,Nothing}=nothing)::Window
    if w == nothing
        w = Window(Dict("webPreferences" => Dict("webSecurity" => false)))  # to load local files
        title(w, "SpmImage Tycoon")
    end

    images_parsed = parse_files(dir_data)  # TODO: parse and display image one by one

    file_GUI = path_asset("GUI.html")
    file_GUI_css = path_asset("GUI.css")
    file_GUI_js = path_asset("GUI.js")
    file_CSS = path_asset("bulma.min.css")
    dir_asset = path_asset("");
    # file_Blink_js = resolve_blink_asset("res", "blink.js")

    # loadfile(w, file_GUI)  # this is probably a bit "bold", as it replaces the whole content (including the basic blink.js, which we have to reload in the next line)
    # load!(w, file_Blink_js)
    load!(w, file_GUI)
    load!(w, file_GUI_js)
    load!(w, file_CSS)
    load!(w, file_GUI_css)

    dir_cache = get_dir_cache(dir_data)
    dir_cache_js = add_trailing_slash(dir_cache)

    @js w set_base_href($dir_asset)
    @js w set_dir_cache($dir_cache_js)
    @js w load_page()
    
    ids = collect(1:length(images_parsed))
    filenames = [s.filename_display for s in images_parsed]
    @js_ w load_images($ids, $filenames)

    set_event_handlers(w, dir_data, images_parsed)

    return w
end

end
