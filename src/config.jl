
const config_filename = "settings.json"  # configuration settings
const config_dir = ".spmimagetycoon"  # will be in home directory


# default settings - the ones that are not declared as constants can be overriden by values from the config file
channels_feedback_on = ["Z"]
channels_feedback_off = ["Frequency Shift", "Current"]

const resize_to = 2048  # we set it very high, so probably no images will be resized. A smaller value might improve performance (or not)
const extension_spm = ".sxm"

const dir_cache_name = "_spmimages_cache"  # directory used for caching (julia writes all generated image files here)
const dir_colorbars = "colorbars"  # colorbars will be saved in a subdirectory in the cache directory
const dir_res = "../res/"  # relative to module directory

const show_load_progress_every = 20  # show load progress every n files

const dir_template_odp = abspath(joinpath(@__DIR__, dir_res, "template_odp"))  # template for openoffice document
const odp_ignore_comment_lines = ["User"]   # comment lines starting with these words are ignored
odp_channel_names_short = OrderedDict(  # channel names to be replaced for shorter versions
    "Frequency Shift" => "Δf",
    "Frequency Shift bwd" => "Δf<",
    "Current" => "I",
    "Current bwd" => "I<"
)

const filename_db = "db.jld2"  # save all data to this file (in cache_dir)
auto_save_minutes = 10  # auto-save every n minutes

last_directories = []  # last opened directories (will be populated from the config file)
const last_directories_max = 20  # max number of last directories to save

const background_correction_list = OrderedDict{String,Background}(
    "none" => no_correction,
    "offset" => subtract_minimum,
    "plane" => plane_linear_fit,
    "line average" => line_average,
    "vline average" => vline_average,
    "line linear" => line_linear_fit,
    "vline linear" => vline_linear_fit,
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
        d = JSON.parsefile(config_filepath)
        if haskey(d, "channels_feedback_on") && isa(d["channels_feedback_on"], Array)
            global channels_feedback_on = string.(d["channels_feedback_on"])
        end

        if haskey(d, "channels_feedback_off") && isa(d["channels_feedback_off"], Array)
            global channels_feedback_off = string.(d["channels_feedback_off"])
        end

        if haskey(d, "auto_save_minutes") && isa(d["auto_save_minutes"], Real)
            global auto_save_minutes = d["auto_save_minutes"]
        end

        if haskey(d, "last_directories") && isa(d["last_directories"], Array)
            global last_directories = string.(d["last_directories"])
        end

        if haskey(d, "export")
            if haskey(d["export"], "channel_names_short") && isa(d["export"]["channel_names_short"], Dict)
                global odp_channel_names_short = OrderedDict{String,String}()
                for (k,v) in d["export"]["channel_names_short"]
                    odp_channel_names_short[string[k]] = string[v]
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
    d = OrderedDict(
        "channels_feedback_on" => channels_feedback_on,
        "channels_feedback_off" => channels_feedback_off,
        "auto_save_minutes" => auto_save_minutes,
        "export" => odp_channel_names_short,
        "last_directories" => last_directories
    )

    try
        open(config_filepath,"w") do f
            JSON.print(f, d, 4)
        end
    catch e
        println("Error: Could not write config file $config_filepath.")
        println(e)
    end
end
