# for memory caching of spectra
const spectrum_cache_order = Deque{String}()
const spectrum_cache = Dict{String,SpmSpectrum}()


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
        if y_inverted && x_inverted # (inv, inv) -> (0, 0)
            griditem.channel_range_selected[1], griditem.channel_range_selected[2] = griditem.channel_range_selected[2], griditem.channel_range_selected[1]
            griditem.channel_range_selected[3], griditem.channel_range_selected[4] = griditem.channel_range_selected[4], griditem.channel_range_selected[3]
        elseif y_inverted # (inv, 0) -> (0, inv)
            griditem.channel_range_selected[1], griditem.channel_range_selected[2] = griditem.channel_range_selected[2], griditem.channel_range_selected[1]
            griditem.channel_range_selected[3], griditem.channel_range_selected[4] = griditem.channel_range_selected[4], griditem.channel_range_selected[3]
        elseif x_inverted # (0, inv) -> (inv, inv)
            griditem.channel_range_selected[1], griditem.channel_range_selected[2] = griditem.channel_range_selected[2], griditem.channel_range_selected[1]
        else # (0, 0) -> (inv, 0)
            griditem.channel_range_selected[1], griditem.channel_range_selected[2] = griditem.channel_range_selected[2], griditem.channel_range_selected[1]
        end
    end
    return nothing
end


"""sets selected range and recreates spectra"""
function set_range_selected_spectrum!(ids::Vector{String}, dir_data::String, images_parsed::Dict{String,SpmGridItem}, range_selected::Array{Float64})::Nothing
    dir_cache = get_dir_cache(dir_data)
    for id in ids  # we could use threads here as well, but so far we only do this for one image at once (and threads seem to make it a bit more unstable)
        filename_original = images_parsed[id].filename_original
        spectrum = load_spectrum_cache(joinpath(dir_data, images_parsed[id].filename_original))
        images_parsed[id].channel_range_selected = range_selected
        create_spectrum!(images_parsed[id], spectrum, base_dir=dir_cache)
    end
    return nothing
end

"""
    function load_spectrum_cache(filename::AbstractString)::SpmSpectrum

Loads a spectrum from either the file or the memory cache.
"""
function load_spectrum_cache(filename::AbstractString)::SpmSpectrum
    if haskey(spectrum_cache, filename)
        push!(spectrum_cache_order, filename)

        # we should make sure that `spectrum_cache_order` does not fill up too much
        while length(spectrum_cache_order) > 100000
            to_delete = popfirst!(spectrum_cache_order)
            if haskey(spectrum_cache, to_delete)
                delete!(spectrum_cache, to_delete)
            end
        end
        
        if haskey(spectrum_cache, filename)
            return spectrum_cache[filename]
        end
    end

    spectrum = load_spectrum(filename, index_column=true, index_column_type=Float64)

    # keep cache size roughly within the limit set in the config
    while Base.summarysize(spectrum_cache) > memcache_mb_spectra * 1e6 && length(spectrum_cache) > 0
        to_delete = popfirst!(spectrum_cache_order)
        if haskey(spectrum_cache, to_delete)
            delete!(spectrum_cache, to_delete)
        end
    end

    # add to cache
    spectrum_cache[filename] = spectrum
    push!(spectrum_cache_order, filename)
    return spectrum
end


"""Get, background correct and filter image data for a specific griditem.
If `sort_x_asc` is `true` then the data is sorted by x_data in ascending direction.
If `sort_x_any` is `true``, then the data is sorted by x_data in ascending direction if it is not yet sorted in ascending or descending direction.
Returns a vector for xdata and a vector of vectors for the ydata, as well as a vector of strings for the colors.
"""
function get_spectrum_data(griditem::SpmGridItem, spectrum::SpmSpectrum; sort_x_asc::Bool=false, sort_x_any::Bool=false)::Tuple{Vector{Vector{Float64}},Vector{Vector{Float64}},Vector{String}}
    # TODO: implement average sweeps
    channel_name = griditem.channel_name
    channel2_name = griditem.channel2_name
    channel_name_bwd = griditem.channel_name * " [bwd]"
    channel2_name_bwd = griditem.channel2_name * " [bwd]"

    # how to get the data from the dataframe, ! means by reference, : means copy
    # we do not want any of the vectors to be a reference of any other
    sel_fwd = !
    sel_bwd = !
    sel2_fwd = !
    sel2_bwd = !

    if channel_name == channel2_name
        sel2_fwd = :;
        sel2_bwd = :;
    end

    bwd_available = findfirst(endswith(" [bwd]"), spectrum.channel_names) !== nothing
    if bwd_available
        # there is no bwd-channel for "Index", but for all others there should be
        if channel_name_bwd ∉ spectrum.channel_names
            channel_name_bwd = channel_name
            sel_bwd = :;
        end
        if channel2_name_bwd ∉ spectrum.channel_names
            channel2_name_bwd = channel2_name
            sel2_bwd = :;
        end
    end

    if griditem.scan_direction == 0  # only forward channel
        y_datas = [spectrum.data[!, channel_name]]
        x_datas = [spectrum.data[sel2_fwd, channel2_name]]
        colors = [color_spectrum_fwd]
    elseif griditem.scan_direction == 1  # only backward channel
        if bwd_available
            y_datas = [spectrum.data[!, channel_name_bwd]]
            x_datas = [spectrum.data[sel2_bwd, channel2_name_bwd]]
            colors = [color_spectrum_bwd]
        else
            y_datas = [spectrum.data[!, channel_name]]
            x_datas = [spectrum.data[sel2_fwd, channel2_name]]
            colors = [color_spectrum_fwd]
        end
    else  # both channels
        if bwd_available
            y_datas = [spectrum.data[!, channel_name], spectrum.data[sel_bwd, channel_name_bwd]]
            x_datas = [spectrum.data[sel2_fwd, channel2_name], spectrum.data[sel2_bwd, channel2_name_bwd]]
            colors = [color_spectrum_fwd, color_spectrum_bwd]
        else
            y_datas = [spectrum.data[!, channel_name]]
            x_datas = [spectrum.data[sel2_fwd, channel2_name]]
            colors = [color_spectrum_fwd]
        end
    end

    for (x_data, y_data) in zip(x_datas, y_datas)
        if sort_x_asc
            if !issorted(x_data)
                p = sortperm(x_data)
                x_data .= x_data[p]
                y_data .= y_data[p]
            end
        elseif sort_x_any && !issorted(x_data) && !issorted(x_data, rev=true)
            p = sortperm(x_data)
            x_data .= x_data[p]
            y_data .= y_data[p]
        end
        SpmSpectroscopy.correct_background!(x_data, y_data, background_correction_list_spectrum[griditem.background_correction])
    end

    return x_datas, y_datas, colors
end


"""gets spectrum data to be used in the js-plot function."""
function get_spectrum_data_dict(griditem::SpmGridItem, dir_data::String)::Dict{String,Any}
    type = "line"
    zip_data = false
    spectrum = load_spectrum_cache(joinpath(dir_data, griditem.filename_original))
    x_datas, y_datas, colors = get_spectrum_data(griditem, spectrum, sort_x_asc=true)  # uplot needs ascending x_values
    
    i = 1
    for (x_data,y_data) in zip(x_datas,y_datas)
        if i > 1 && x_data != x_datas[1]  # uplot.js needs tone common x-axis
            zip_data = true
            type = "scatter"
        end
        i += 1
    end

    new_length = length(y_datas[1]) * length(y_datas)
    x_data_new = Vector{Float64}(undef, new_length)
    y_datas_new = [Vector{Float64}(undef, new_length) for _ in 1:length(y_datas)]
    if zip_data  # uplot.js wants one common x_data, so we join the data now
        idx = 1
        for i_point = 1:length(y_datas[1])
            x_datas_points = [x_data_curr[i_point] for x_data_curr in x_datas]
            p = sortperm(x_datas_points)
            for i_order in 1:length(p)
                x_data_new[idx] = x_datas_points[p[i_order]]
                for i_channel in 1:length(p)
                    y_datas_new[i_channel][idx] = (p[i_order] == i_channel) ? y_datas[i_channel][i_point] : NaN
                end
                idx += 1
            end
        end
    else
        x_data_new = x_datas[1]
        y_datas_new = y_datas
    end

    if length(griditem.channel_range_selected) != 4
        griditem.channel_range_selected = [0., 1., 0., 1.]
    end
    x_inverted = (griditem.channel_range_selected[3] > griditem.channel_range_selected[4]) ? true : false
    y_inverted = (griditem.channel_range_selected[1] > griditem.channel_range_selected[2]) ? true : false
    if x_inverted
        reverse!(x_data_new)
        x_data_new .*= -1.
    end
    for y_data_new in y_datas_new
        if x_inverted
            reverse!(y_data_new)
        end
        if y_inverted
            y_data_new .*= -1.
        end
    end

    type = "line"  # let's always do a line for now
    spectrum_data = Dict{String,Any}("x_data" => x_data_new, "y_datas" => y_datas_new, "colors" => colors, "type" => type, "x_inverted" => x_inverted, "y_inverted" => y_inverted)
    return spectrum_data
end


"""
    function save_spectrum_svg(filename::AbstractString, x_datas::AbstractVector{<:AbstractVector}, y_datas::AbstractVector{<:AbstractVector},
        colors::AbstractVector{<:AbstractString}; range_selected::Vector{Float64}=[0.,1.,0.,1.])::Vector{Float64}

Saves a graph of multiple curves to a SVG file (`filename`). Each curve is represented by an element in the vectors `x_datas`, `y_datas` and `colors`.
A relative zoom can be specified in a four-element vector `range_selected`.
Returns the ranges of y_datas and x_data.
"""
function save_spectrum_svg(filename::AbstractString, x_datas::AbstractVector{<:AbstractVector}, y_datas::AbstractVector{<:AbstractVector},
        colors::AbstractVector{<:AbstractString}; range_selected::Vector{Float64}=[0.,1.,0.,1.])::Vector{Float64}

    @assert length(y_datas) == length(colors)
    if length(range_selected) != 4
        range_selected = [0., 1., 0., 1.]
    end
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
        yxranges = [y_minmax[1], y_minmax[2], x_minmax[1], x_minmax[2]]


        # absolute selected range-span in x and y, should always be != 0
        yxranges_selected = [
            yxranges[1] + (yxranges[2] - yxranges[1]) * range_selected[1],
            yxranges[1] + (yxranges[2] - yxranges[1]) * range_selected[2],
            yxranges[3] + (yxranges[4] - yxranges[3]) * range_selected[3],
            yxranges[3] + (yxranges[4] - yxranges[3]) * range_selected[4]
        ]
        x_delta = yxranges_selected[4] - yxranges_selected[3]
        if x_delta == 0. 
            x_delta += 1e16
        end
        y_delta = yxranges_selected[2] - yxranges_selected[1]
        if y_delta == 0. 
            y_delta += 1e-16
        end

        x_scale = 100. / x_delta
        y_scale = 100. / y_delta

        @views @inbounds for i in 1:length(y_datas)
            x_data_plot = @. round((x_datas[i] - yxranges_selected[3]) * x_scale, digits=2)
            y_data_plot = @. round(100 - ((y_datas[i] - yxranges_selected[1]) * y_scale), digits=2)

            points = ""
            @views @inbounds for j in 1:length(x_data_plot)
                points *= "$(x_data_plot[j]),$(y_data_plot[j]) "
            end
            write(f, polyline_header_1 * colors[i] * polyline_header_2 * points * polyline_footer)
        end
        write(f, svg_footer)
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
    x_datas, y_datas, colors = get_spectrum_data(griditem, spectrum, sort_x_any=true)  # sort x_values (asc or desc is ok), so that we get a nice line plot
    griditem.points = length(x_datas[1])

    filename_display = "$(griditem.filename_original[1:end-4])_$(griditem.virtual_copy).svg"
    f = joinpath(base_dir, filename_display)
    yxranges = save_spectrum_svg(f, x_datas, y_datas, colors, range_selected=griditem.channel_range_selected)

    griditem.channel_range = yxranges

    griditem.filename_display = filename_display
    griditem.filename_display_last_modified = unix2datetime(mtime(f))
    return nothing
end


"""Parses a spectrum file and creates the preview in the cache directory if necessary."""
function parse_spectrum!(images_parsed::Dict{String, SpmGridItem}, virtual_copies_dict::Dict{String,Array{SpmGridItem}},
    images_parsed_new::Vector{String}, only_new::Bool,
    dir_cache::String, datafile::String, id::String, filename_original::String, created::DateTime, last_modified::DateTime)::Nothing

    spectrum = load_spectrum_cache(datafile)

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