

# default settings (should be overriden by config file later)
const channels_feedback = ["Z"]
const channels_no_feedback = ["Frequency Shift", "Current"]

const resize_to = 2048  # we set it very high, so probably no images will be resized. A smaller value might improve performance (or not)
const extension_spm = ".sxm"

const dir_cache_name = "_spmimages_cache"  # TODO: move this to user directory (and use unique folder names)
const dir_colorbars = "colorbars"  # colorbars will be saved in a subdirectory in the cache directory
const dir_res = "../res/"  # relative to module directory

const dir_template_odp = joinpath(dir_res, "template_odp")  # template for openoffice document
const odp_ignore_comment_lines = ["User"]   # comment lines starting with these words are ignored
const odp_channel_names_short = Dict(  # channel names to be replaced for shorter versions
    "Frequency Shift" => "Δf",
    "Frequency Shift bwd" => "Δf<",
    "Current" => "I",
    "Current bwd" => "I<"
)

const filename_db = "db.jld2"  # save all data to this file (in cache_dir)
const auto_save_minutes = 10  # auto-save every n minutes


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
