"""replaces some characters for their UTF-8 and strips non-UTF8 characters"""
function utf8ify(s::AbstractString)::String
    s = replace(s, "\xb0" => "°")
    # TODO: replace other characters too
    return filter(isvalid, s)
end


"""scales and offsets an array, so that each value lies between 0 and 1.
If range_selected is given, this range is normalized to lie between 0 and 1.
Returns the minimum and maximum value of the original array."""
function normalize01!(d::AbstractArray; range_selected::Vector{<:Number}=Float64[])::Tuple{Number,Number}
    d_ = skipnan(d)
    if !isempty(d_)
        vmin_original, vmax_original = extrema(d_)  # minimum and maximum function return NaN otherwise
    else
        vmin_original = 0
        vmax_original = 0
    end
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


"""adds a trailing slash to a directory if necessary"""
function add_trailing_slash(directory::String)::String
    return joinpath(directory, "")
end


"""returns the base filename for .nc files"""
function base_filename(filename::String)::String
    filename = basename(filename)
    if is_gxsm_image(filename)
        return split(filename, "-", limit=2)[1] * "~merged" * extension_image_gxsm
    elseif is_gxsm_spectrum(filename)
        # we wouldn't need this in principle, but this is to avoid name conflicts (if there a nanonis spectrum with the same name as a GXSM spectrum)
        return splitext(filename)[1] * "~vpdata" * extension_spectrum_gxsm
    else
        return filename
    end
end


"""Gets a list of the files for each channel in `fnames`. Used for GXSM files, for which each channel is stored in a separate file."""
function get_channels_names_files(fnames::Vector{String})::Dict{String, String}
    names, units, files_fwd, files_bwd = SpmImages.get_channel_names_units_netCDF(basename.(fnames))
    res = Dict{String, String}()
    for n in names
        haskey(files_fwd, n) && (res[n] = files_fwd[n])
        haskey(files_bwd, n) && (res[image_channel_name_bwd(n)] = files_bwd[n])
    end
    return res
end


"""get contents of filename"""
function get_contents(filename::String)::String
    contents = open(filename) do file
        read(file, String)
    end
    return contents
end


"""returns the cache directory (which is a subdirectory of dir_data"""
function get_dir_cache(dir_data::String)::String
    return joinpath(dir_data, dir_cache_name)
end


"""returns temp cache from dir_data"""
function get_dir_temp_cache(dir_data::String)::String
    d = splitdir(dir_data)[end]
    return joinpath(tempdir(), dir_temp_cache_name, dir_cache_name, d)
end


"""returns temp cache from dir_data"""
function get_dir_temp_cache_cache(dir_cache::String)::String
    dir_data = splitdir(dir_cache)[1]
    return get_dir_temp_cache(dir_data)
end


"""Returns the absolute path to an asset"""
function path_asset(asset::String)::String
    return abspath(joinpath(@__DIR__, dir_res, asset))
end


"""cecks if the filename is an image"""
function is_image(filename::String)::Bool
    return endswith(filename, extension_image_nanonis) || endswith(filename, extension_image_gxsm) ||
        endswith(filename, extension_image_ibw)
end


"""checks if the filename is a spectrrum"""
function is_spectrum(filename::String)::Bool
    return endswith(filename, extension_spectrum_nanonis) || endswith(filename, extension_spectrum_gxsm)
end