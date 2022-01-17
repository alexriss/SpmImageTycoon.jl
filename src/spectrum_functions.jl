"""gets the default channel name for the y-axis and x-axis, as well as their units, 
according to the lists spectrum_channels and spectrum_channels_x in config.jl
and the type of the experiment."""
function default_channel_names_units(spectrum::SpmSpectrum)::Tuple{String,String,String,String}
    channel_name = spectrum.channel_names[2]   # yaxis
    channel_unit = spectrum.channel_units[2]
    channel2_name = spectrum.channel_names[1]  # xaxis
    channel2_unit = spectrum.channel_units[1]

    if haskey(spectrum.header, "Experiment")
        experiment = spectrum.header["Experiment"] 
        channels = String[]
        channels2 = String[]
        if haskey(spectrum_channels, experiment)
            channels = spectrum_channels[experiment]
        end
        if haskey(spectrum_channels_x, experiment)
            channels2 = spectrum_channels_x[experiment]
        end
        if length(channels) > 0
            for c in channels
                if c in spectrum.channel_names
                    channel_name = c

                    # get corresponding unit
                    c_idx = findfirst(isequal(c), spectrum.channel_names)
                    channel_unit = spectrum.channel_units[c_idx]
                    break
                end
            end
        end
        if length(channels2) > 0
            for c in channels2
                if c in spectrum.channel_names
                    channel2_name = c

                    # get corresponding unit
                    c_idx = findfirst(isequal(c), spectrum.channel_names)
                    channel2_unit = spectrum.channel_units[c_idx]
                    break
                end
            end
        end
    end

    return channel_name, channel_unit, channel2_name, channel2_unit
end


"""Gets the next channel name and corresponding unit of `spectrum`, skipping all backwards channels."""
function next_channel_name_unit(spectrum::SpmSpectrum, channel_name::String, jump::Int)::Tuple{String, String}
    channel_names = filter(!endswith(" [bwd]"), spectrum.channel_names)

    i = findfirst(x -> x == channel_name, channel_names)
    if i === nothing  # this should never happen anyways
        next_channel_name = channel_names[1]
    else
        i = (i + jump - 1) % length(channel_names) + length(channel_names)
        i = i % length(channel_names) + 1
        next_channel_name = channel_names[i]
    end

    # get unit
    i = findfirst(x -> x == next_channel_name, spectrum.channel_names)
    next_channel_unit = spectrum.channel_units[i]

    return next_channel_name, next_channel_unit
end


"""Sets the next channel name for the griditem."""
function next_channel_name!(griditem::SpmGridItem, spectrum::SpmSpectrum, jump::Int)::Nothing
    channel_name, channel_unit = next_channel_name_unit(spectrum, griditem.channel_name, jump)
    griditem.channel_name = channel_name
    griditem.channel_unit = channel_unit

    if length(griditem.channel_range_selected) != 0
         # reset selected range when switching channel (we try to keep it for all other cases for now)
        griditem.channel_range_selected[1] = 0
        griditem.channel_range_selected[2] = 1
    end
    return nothing
end


"""Sets the next channel2 name for the griditem, dummy function for images."""
function next_channel2_name!(griditem::SpmGridItem, spectrum::SpmSpectrum, jump::Int)::Nothing
    channel2_name, channel2_unit = next_channel_name_unit(spectrum, griditem.channel2_name, jump)
    griditem.channel2_name = channel2_name
    griditem.channel2_unit = channel2_unit
    
    if length(griditem.channel_range_selected) != 0
         # reset selected range when switching channel (we try to keep it for all other cases for now)
        griditem.channel_range_selected[3] = 0
        griditem.channel_range_selected[4] = 1
    end
    return nothing
end


# toggles between forwards and backward scan
function next_direction!(griditem::SpmGridItem, spectrum::SpmSpectrum)::Nothing
    griditem.scan_direction = (griditem.scan_direction + 1) % 3
    return nothing
end


"""Sets the next background_correction key in the list of possible background corrections"""
function next_background_correction!(griditem::SpmGridItem, spectrum::SpmSpectrum, jump::Int)::Nothing
    keys_bg = collect(keys(background_correction_list_spectrum))
    i = findfirst(x -> x == griditem.background_correction, keys_bg)
    i = (i + jump - 1) % length(background_correction_list_spectrum) + length(background_correction_list_spectrum)
    i = i % length(background_correction_list_spectrum) + 1
    griditem.background_correction = keys_bg[i]
    return nothing
end


"""Sets the next colorscheme key in the list of possible colorschemes, dummy function for spectra"""
function next_colorscheme!(griditem::SpmGridItem, spectrum::SpmSpectrum, jump::Int)::Nothing
    return nothing
end


"""Sets the inverted colorscheme key in the list of possible colorschemes"""
function next_invert!(griditem::SpmGridItem, spectrum::SpmSpectrum)::Nothing
    if length(griditem.channel_range_selected) == 0
        griditem.channel_range_selected = [1, 0, 0, 1]  # invert ydata
    else
        y_inverted = griditem.channel_range_selected[1] > griditem.channel_range_selected[2]
        x_inverted = griditem.channel_range_selected[3] > griditem.channel_range_selected[4]
        if y_inverted && x_inverted
            griditem.channel_range_selected[1], griditem.channel_range_selected[2] = griditem.channel_range_selected[2], griditem.channel_range_selected[1]
            griditem.channel_range_selected[3], griditem.channel_range_selected[4] = griditem.channel_range_selected[4], griditem.channel_range_selected[3]
        elseif y_inverted
            griditem.channel_range_selected[3], griditem.channel_range_selected[4] = griditem.channel_range_selected[4], griditem.channel_range_selected[3]
        else  # if none inverted or x_inverted
            griditem.channel_range_selected[1], griditem.channel_range_selected[2] = griditem.channel_range_selected[2], griditem.channel_range_selected[1]
        end
    end
    return nothing
end



"""Get, background correct and filter image data for a specific griditem.
Returns a vector for xdata and a vector of vectors for the ydata, as well as a vector of strings for the colors."""
function get_spectrum_data(griditem::SpmGridItem, spectrum::SpmSpectrum)::Tuple{Vector{Vector{Float64}},Vector{Vector{Float64}},Vector{String}}
    # TODO: implement average sweeps
    channel_name = griditem.channel_name
    channel2_name = griditem.channel2_name
    channel_name_bwd = griditem.channel_name * " [bwd]"
    channel2_name_bwd = griditem.channel2_name * " [bwd]"

    bwd_available = findfirst(endswith(" [bwd]"), spectrum.channel_names) !== nothing
    if bwd_available
        # there is no bwd-channel for "Index", but for all others there should be
        if channel_name_bwd ∉ spectrum.channel_names
            channel_name_bwd = channel_name
        end
        if channel2_name_bwd ∉ spectrum.channel_names
            channel2_name_bwd = channel2_name
        end
    end

    if griditem.scan_direction == 0  # only forward channel
        y_datas = [spectrum.data[!, channel_name]]
        x_datas = [spectrum.data[!, channel2_name]]
        colors = [color_spectrum_fwd]
    elseif griditem.scan_direction == 1  # only backward channel
        if bwd_available
            y_datas = [spectrum.data[!, channel_name_bwd]]
            x_datas = [spectrum.data[!, channel2_name_bwd]]
            colors = [color_spectrum_bwd]
        else
            y_datas = [spectrum.data[!, channel_name]]
            x_datas = [spectrum.data[!, channel2_name]]
            colors = [color_spectrum_fwd]
        end
    else  # both channels
        if bwd_available
            y_datas = [spectrum.data[!, channel_name], spectrum.data[!, channel_name_bwd]]
            x_datas = [spectrum.data[!, channel2_name], spectrum.data[!, channel2_name_bwd]]
            colors = [color_spectrum_fwd, color_spectrum_bwd]
        else
            y_datas = [spectrum.data[!, channel_name]]
            x_datas = [spectrum.data[!, channel2_name]]
            colors = [color_spectrum_fwd]
        end
    end

    for (x_data, y_data) in zip(x_datas, y_datas)
        SpmSpectroscopy.correct_background!(x_data, y_data, background_correction_list_spectrum[griditem.background_correction])
    end

    return x_datas, y_datas, colors
end


"""
    function save_spectrum_svg(filename::AbstractString, x_datas::AbstractVector{<:AbstractVector}, y_datas::AbstractVector{<:AbstractVector}, colors::AbstractVector{<:AbstractString})::Vector{Float64}

Saves a graph of multiple curves to a SVG file (`filename`). Each curve is represented by an element in the vectors `x_datas`, `y_datas` and `colors`.
Returns the ranges of y_datas and x_data.
"""
function save_spectrum_svg(filename::AbstractString, x_datas::AbstractVector{<:AbstractVector}, y_datas::AbstractVector{<:AbstractVector}, colors::AbstractVector{<:AbstractString})::Vector{Float64}
    svg_header = """<?xml version="1.0" encoding="utf-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1000 1000">
    """
    svg_footer = "</svg>"
    polyline_header_1 = """<polyline style="stroke:"""  # insert color here
    polyline_header_2 = """; stroke-linecap:butt; stroke-linejoin:round; stroke-width:12; stroke-opacity:0.6; fill:none" points=\""""
    polyline_footer = """"/>\n"""

    @assert length(y_datas) == length(colors)
    yxranges = Float64[]

    open(filename, "w") do f
        write(f, svg_header)

        # get minimum and maximum values for all data
        x_minmax = [x_datas[1][1], x_datas[1][1]]
        y_minmax = [y_datas[1][1], y_datas[1][1]]
        for i in 1:length(y_datas)
            x_minmaxi = extrema(x_datas[i])
            x_minmax[1] = min(x_minmax[1], x_minmaxi[1])
            x_minmax[2] = max(x_minmax[2], x_minmaxi[2])
            y_minmaxi = extrema(y_datas[i])
            y_minmax[1] = min(y_minmax[1], y_minmaxi[1])
            y_minmax[2] = max(y_minmax[2], y_minmaxi[2])
        end

        x_scale = 1000 / (x_minmax[2] - x_minmax[1])
        y_scale = 1000 / (y_minmax[2] - y_minmax[1])
        @views @inbounds for i in 1:length(y_datas)
            x_data_plot = @. round((x_datas[i] - x_minmax[1]) * x_scale, digits=2)
            y_data_plot = @. round(1000 - (y_datas[i] - y_minmax[1]) * y_scale, digits=2)

            points = ""
            @views @inbounds for j in 1:length(x_data_plot)
                points *= "$(x_data_plot[j]),$(y_data_plot[j]) "
            end
            write(f, polyline_header_1 * colors[i] * polyline_header_2 * points * polyline_footer)
        end
        write(f, svg_footer)
        yxranges = [y_minmax[1], y_minmax[2], x_minmax[1], x_minmax[2]]
    end
    return yxranges
end


"""Creates and saves a svg image for channel_name vs channel2_name.
The "filename_display" field of the SpmGridItem is updated (to the svg filename without the directory prefix)
if use_existing is true, then an updated image will only be generated if the last-modified date of the image does not correspon to the one save in the db."""
function create_spectrum!(griditem::SpmGridItem, spectrum::SpmSpectrum; base_dir::String="", use_existing::Bool=false)
    if use_existing
        f = joinpath(base_dir, griditem.filename_display)
        if unix2datetime(mtime(f)) == griditem.filename_display_last_modified  # mtime will give 0 for files that do not exist (so we do not need to check if file exists)
            return nothing  # image exists, nothing to do
        end
    end

    # load spectrum
    x_data, y_datas, colors = get_spectrum_data(griditem, spectrum)
    griditem.points = length(x_data)

    filename_display = "$(griditem.filename_original[1:end-4])_$(griditem.virtual_copy).svg"
    f = joinpath(base_dir, filename_display)
    yxranges = save_spectrum_svg(f, x_data, y_datas, colors)

    griditem.channel_range = yxranges

    griditem.filename_display = filename_display
    griditem.filename_display_last_modified = unix2datetime(mtime(f))
    return nothing
end


"""Parses a spectrum file and creates the preview in the cache directory if necessary."""
function parse_spectrum!(images_parsed::Dict{String, SpmGridItem}, virtual_copies_dict::Dict{String,Array{SpmGridItem}},
    images_parsed_new::Vector{String}, only_new::Bool,
    dir_cache::String, datafile::String, id::String, filename_original::String, created::DateTime, last_modified::DateTime)::Nothing

    spectrum = load_spectrum(datafile, index_column=true, index_column_type=Float64)

    z_feedback_setpoint = 0.0
    z_feedback_setpoint_unit = ""
    if haskey(spectrum.header, "Z-Controller>Setpoint")
        z_feedback_setpoint = parse(Float64, spectrum.header["Z-Controller>Setpoint"])
    end
    if haskey(spectrum.header, "Z-Controller>Setpoint unit")
        z_feedback_setpoint_unit = spectrum.header["Z-Controller>Setpoint unit"]
    end

    # sometimes x and y coordinates can be NaN (this happens for history data)
    # then we get the first point if available
    if isnan(spectrum.position[1])
        if "X" in spectrum.channel_names
            spectrum.position[1] = spectrum.data[1, "X"]
        end
    end
    if isnan(spectrum.position[2])
        if "Y" in spectrum.channel_names
            spectrum.position[2] = spectrum.data[1, "Y"]
        end
    end

    if haskey(images_parsed, id)
        griditem = images_parsed[id]
        # still update a few fields (the files may have changed) - but most of these fields should stay unchanged
        griditem.type = SpmGridSpectrum
        griditem.filename_original = filename_original
        griditem.created = created
        griditem.last_modified = last_modified
        griditem.recorded = spectrum.start_time
        griditem.center = spectrum.position .* 1e9  # convert to nm
        griditem.bias = spectrum.bias
        griditem.z_feedback = spectrum.z_feedback
        griditem.z_feedback_setpoint = z_feedback_setpoint
        griditem.z_feedback_setpoint_unit = z_feedback_setpoint_unit
        griditem.z = spectrum.position[3]
        griditem.comment = utf8ify(spectrum.header["User"])  # TODO: check if this is correct
        griditem.status = 0
    else
        # get the respective image channel (depending on whether the feedback was on or not)
        channel_name, channel_unit, channel2_name, channel2_unit = default_channel_names_units(spectrum)
        images_parsed[id] = SpmGridItem(
            id=id, type=SpmGridSpectrum, filename_original=filename_original, created=created, last_modified=last_modified, recorded=spectrum.start_time,
            channel_name=channel_name, channel_unit=channel_unit, channel2_name=channel2_name, channel2_unit=channel2_unit,
            center=spectrum.position .* 1e9, scan_direction=2, 
            bias=spectrum.bias, z_feedback=spectrum.z_feedback,
            z_feedback_setpoint=z_feedback_setpoint, z_feedback_setpoint_unit=z_feedback_setpoint_unit, z=spectrum.position[3],
            comment=utf8ify(spectrum.header["User"])
        )
        if only_new
            push!(images_parsed_new, id)
        end
        griditem = images_parsed[id]
    end
    Threads.@spawn create_spectrum!(griditem, spectrum, base_dir=dir_cache, use_existing=true)
    
    # virtual copies
    if haskey(virtual_copies_dict, id)
        for virtual_copy in virtual_copies_dict[id]
            griditem = images_parsed[virtual_copy.id]
            # update fields here, too - however, most of these fields should stay unchanged
            griditem.type = SpmGridSpectrum
            griditem.filename_original = filename_original
            griditem.created = created
            griditem.last_modified = last_modified
            griditem.recorded = spectrum.start_time
            griditem.center = spectrum.position .* 1e9  # convert to nm
            griditem.bias = spectrum.bias
            griditem.z_feedback = spectrum.z_feedback
            griditem.z_feedback_setpoint = z_feedback_setpoint
            griditem.z_feedback_setpoint_unit = z_feedback_setpoint_unit
            griditem.z = spectrum.position[3]
            griditem.comment = utf8ify(spectrum.header["User"])  # TODO: check if this is correct
            griditem.status = 0

            Threads.@spawn create_spectrum!(griditem, spectrum, base_dir=dir_cache, use_existing=true)
        end
    end
    return nothing
end