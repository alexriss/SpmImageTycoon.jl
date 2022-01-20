
const config_filename = "settings.toml"  # configuration settings
const config_dir = ".spmimagetycoon"  # will be in home directory


# default settings - the ones that are not declared as constants can be overriden by values from the config file
image_channels_feedback_on = ["Z"]
image_channels_feedback_off = ["Frequency Shift", "Current"]
spectrum_channels = OrderedDict{String,Vector{String}}(
    "bias spectroscopy" => ["LIX 1 omega", "Frequency Shift", "Current"],
    "Z spectroscopy" => ["Frequency Shift", "Current"],
    "History Data" => ["Current", "Frequency Shift"]
)
spectrum_channels_x = OrderedDict{String,Vector{String}}(
    "History Data" => ["Index"]
)

const resize_to = 2048  # we set it very high, so probably no images will be resized. A smaller value might improve performance (or not)
const extension_image = ".sxm"
const extension_spectrum = ".dat"

const dir_cache_name = "_spmimages_cache"  # directory used for caching (julia writes all generated image files here)
const dir_colorbars = "colorbars"  # colorbars will be saved in a subdirectory in the cache directory
const dir_res = "../res/"  # relative to module directory

const show_load_progress_every = 20  # show load progress every n files

const dir_template_odp = abspath(joinpath(@__DIR__, dir_res, "template_odp"))  # template for openoffice document
const odp_ignore_comment_lines = ["User"]   # comment lines starting with these words are ignored
odp_channel_names_short = OrderedDict{String,String}(  # channel names to be replaced for shorter versions
    "Frequency Shift" => "Δf",
    "Frequency Shift bwd" => "Δf<",
    "Current" => "I",
    "Current bwd" => "I<"
)

const filename_db = "db.jld2"  # save all data to this file (in cache_dir)
auto_save_minutes = 10  # auto-save every n minutes

overview_max_images = 100  # maximum number of images displayed in the filter_overview

memcache_mb_spectra = 50  # size of memory cache for spectra (in mb)

last_directories = []  # last opened directories (will be populated from the config file)
const last_directories_max = 20  # max number of last directories to save

const background_correction_list_image = OrderedDict{String,SpmImages.Background}(
    "none" => SpmImages.no_correction,
    "plane" => SpmImages.plane_linear_fit,
    "line average" => SpmImages.line_average,
    "vline average" => SpmImages.vline_average,
    "line linear" => SpmImages.line_linear_fit,
    "vline linear" => SpmImages.vline_linear_fit,
    "offset" => SpmImages.subtract_minimum,
)

const background_correction_list_spectrum = OrderedDict{String,SpmSpectroscopy.Background}(
    "none" => SpmSpectroscopy.no_correction,
    "linear" => SpmSpectroscopy.linear_fit,
    "offset" => SpmSpectroscopy.subtract_minimum,
)

const colorscheme_list_pre = OrderedDict{String,ColorScheme}(
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

const color_spectrum_fwd = "#241571"
const color_spectrum_bwd = "#B80F0A"


# for SVG generation for spectra
const svg_header = """<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 100 100">
"""
const polyline_header_1 = """<polyline style="stroke:"""  # insert color here
const polyline_header_2 = """; stroke-linecap:butt; stroke-linejoin:round; stroke-width:1; stroke-opacity:0.6; fill:none" points=\""""
const polyline_footer = """"/>\n"""
const svg_footer = "</svg>"

# when exporting we change the existing SVG
const svg_header_export = """<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="-18 -5 120 120">
    <style>
        text {
            font-family:Sans,Arial;
            font-size:6px;
            fill:#909090;
        }
        polyline {
           clip-path: url(#graphArea);
        }
    </style>
    <defs>
        <clipPath id="graphArea">
            <rect x="0" y="0" width="100" height="100"/>
        </clipPath>
    </defs>
"""
const svg_footer_export = """
<text x="50" y="108" style="fill:#303030;" text-anchor="middle" alignment-baseline="top">{{ x_axis_label }}</text>
<text x="0" y="0" style="fill:#303030;" text-anchor="middle" alignment-baseline="center" transform="matrix(0 -1 1 0 -3 50)">{{ y_axis_label }}</text>
<rect x="-1" y="-1" width="102" height="102" style="fill:none;stroke-width:0.5;stroke:#606060" />

<text x="-2" y="108" text-anchor="start" alignment-baseline="top">{{ x_axis_min }}</text>
<text x="102" y="108" text-anchor="end" alignment-baseline="top">{{ x_axis_max }}</text>

<text x="-2" y="101" text-anchor="end" alignment-baseline="top">{{ y_axis_min }}</text>
<text x="-2" y="3" text-anchor="end" alignment-baseline="top">{{ y_axis_max }}</text>
   
</svg>"""


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


"""loads config and sets global variables"""
function load_config()
    if !isdir(joinpath(homedir(), config_dir))
        mkpath(joinpath(homedir(), config_dir))
    end

    config_filepath = joinpath(homedir(), config_dir, config_filename)
    if isfile(config_filepath)
        d = TOML.tryparsefile(config_filepath)
        if typeof(d) <: Dict
            if haskey(d, "image_channels_feedback_on") && isa(d["image_channels_feedback_on"], Array)
                global image_channels_feedback_on = string.(d["image_channels_feedback_on"])
            end

            if haskey(d, "image_channels_feedback_off") && isa(d["image_channels_feedback_off"], Array)
                global image_channels_feedback_off = string.(d["image_channels_feedback_off"])
            end

            if haskey(d, "spectrum_channels") && isa(d["spectrum_channels"], Dict)
                global spectrum_channels = OrderedDict{String,Vector{String}}()
                for (k,v) in d["spectrum_channels"]
                    if isa(v, Array)
                        spectrum_channels[string(k)] = string.(v)
                    end
                end
            end

            if haskey(d, "spectrum_channels") && isa(d["spectrum_channels_x"], Dict)
                global spectrum_channels_x = OrderedDict{String,Vector{String}}()
                for (k,v) in d["spectrum_channels_x"]
                    if isa(v, Array)
                        spectrum_channels_x[string(k)] = string.(v)
                    end
                end
            end
            
            if haskey(d, "spectrum_channels_z_spectroscopy") && isa(d["spectrum_channels_z_spectroscopy"], Array)
                global spectrum_channels_z_spectroscopy = string.(d["spectrum_channels_z_spectroscopy"])
            end

            if haskey(d, "auto_save_minutes") && isa(d["auto_save_minutes"], Real)
                global auto_save_minutes = d["auto_save_minutes"]
            end

            if haskey(d, "overview_max_images") && isa(d["overview_max_images"], Real)
                global overview_max_images = d["overview_max_images"]
            end

            if haskey(d, "memcache_mb_spectra") && isa(d["memcache_mb_spectra"], Real)
                global memcache_mb_spectra = d["memcache_mb_spectra"]
            end

            if haskey(d, "last_directories") && isa(d["last_directories"], Array)
                global last_directories = string.(d["last_directories"])
            end

            if haskey(d, "export")
                if haskey(d["export"], "channel_names_short") && isa(d["export"]["channel_names_short"], Dict)
                    global odp_channel_names_short = OrderedDict{String,String}()
                    for (k,v) in d["export"]["channel_names_short"]
                        odp_channel_names_short[string(k)] = string(v)
                    end
                end
            end
        end
    else  # we create the file
        save_config()
    end
end


"""saves config to file"""
function save_config(new_directory::String="")
    if !isdir(joinpath(homedir(), config_dir))
        mkpath(joinpath(homedir(), config_dir))
    end

    if new_directory != ""
        filter!(x -> x != new_directory, last_directories)
        pushfirst!(last_directories, new_directory)
        while length(last_directories) > last_directories_max
            pop!(last_directories)
        end
    end

    config_filepath = joinpath(homedir(), config_dir, config_filename)
    d = OrderedDict{String,Any}(
        "image_channels_feedback_on" => image_channels_feedback_on,
        "image_channels_feedback_off" => image_channels_feedback_off,
        "spectrum_channels" => spectrum_channels,
        "spectrum_channels_x" => spectrum_channels_x,
        "auto_save_minutes" => auto_save_minutes,
        "overview_max_images" => overview_max_images,
        "memcache_mb_spectra" => memcache_mb_spectra,
        "export" => odp_channel_names_short,
        "last_directories" => last_directories
    )

    try
        open(config_filepath,"w") do f
            TOML.print(f, d)
        end
    catch e
        println("Error: Could not write config file $config_filepath.")
        println(e)
    end
end
