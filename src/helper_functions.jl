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