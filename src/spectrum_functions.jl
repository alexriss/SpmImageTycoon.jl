# for memory caching of spectra
const spectrum_cache_order = Deque{String}()
const spectrum_cache = Dict{String,SpmSpectrum}()


"""expands a range between `start` and `stop` by symmetrically shifting `start` and `stop` apart"""
function expand_range(start::Float64, stop::Float64)::Tuple{Float64,Float64}
    reverse = false
    if start > stop
        start, stop = stop, start
        reverse = true
    end

    start = prevfloat(start)
    stop = nextfloat(stop)

    if reverse 
        return stop, start
    else
        return start, stop
    end
end


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
function get_spectrum_data(griditem::SpmGridItem, spectrum::SpmSpectrum; sort_x_asc::Bool=false, sort_x_any::Bool=false)::Tuple{Vector{DataFrame},Vector{String}}
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

    # if x and y channels are the same, we need to duplicate the column and rename it
    if channel_name == channel2_name
        channel2_name_new = "[duplicate]" * channel2_name
        spectrum.data[!, channel2_name_new] = spectrum.data[:, channel2_name]
        channel2_name = channel2_name_new
    end
    if bwd_available && channel_name_bwd == channel2_name_bwd
        channel2_name_bwd_new = "[duplicate]" * channel2_name_bwd
        spectrum.data[!, channel2_name_bwd_new] = spectrum.data[:, channel2_name_bwd]
        channel2_name_bwd = channel2_name_bwd_new
    end

    # we have to always get the data by copy (using `:` or `dropmissing`), because it will be manipulated (and then re-read from the cache)
    if griditem.scan_direction == 0  # only forward channel
        xy_datas = [dropmissing(spectrum.data[!, [channel2_name, channel_name]])] 
        colors = [color_spectrum_fwd]
    elseif griditem.scan_direction == 1  # only backward channel
        if bwd_available
            xy_datas = [dropmissing(spectrum.data[!, [channel2_name_bwd, channel_name_bwd]])]
            colors = [color_spectrum_bwd]
        else
            xy_datas = dropmissing(spectrum.data[!, [channel2_name, channel_name]])
            colors = [color_spectrum_fwd]
        end
    else  # both channels
        if bwd_available
            xy_datas = [dropmissing(spectrum.data[!, [channel2_name, channel_name]]), dropmissing(spectrum.data[!, [channel2_name_bwd, channel_name_bwd]])]
            colors = [color_spectrum_fwd, color_spectrum_bwd]
        else
            xy_datas = [dropmissing(spectrum.data[!, [channel2_name, channel_name]])]
            colors = [color_spectrum_fwd]
        end
    end

    for xy_data in xy_datas
        x_data = xy_data[!, 1]
        y_data = xy_data[!, 2]
        if sort_x_asc
            if !issorted(x_data)  # often it faster to check if it is sorted and only sort if necessary
                sort!(xy_data, 1)
            end
        elseif sort_x_any && !issorted(x_data) && !issorted(x_data, rev=true)
            sort!(xy_data, 1)
        end
        SpmSpectroscopy.correct_background!(x_data, y_data, background_correction_list_spectrum[griditem.background_correction])
    end

    return xy_datas, colors
end


"""gets spectrum data to be used in the js-plot function."""
function get_spectrum_data_dict(griditem::SpmGridItem, dir_data::String)::Dict{String,Any}
    spectrum = load_spectrum_cache(joinpath(dir_data, griditem.filename_original))
    xy_datas, colors = get_spectrum_data(griditem, spectrum, sort_x_asc=true)  # uplot needs ascending x_values
    
    # uplot.js wants one common x_data, so we join the data now
    for xy_data in xy_datas
        rename!(xy_data, 1 => :x)
    end
    if length(xy_datas) > 1
        xy_datas_comb = outerjoin(xy_datas..., on = :x)
    else
        xy_datas_comb = xy_datas[1]
    end
    x_data = xy_datas_comb[!, 1]
    y_datas = [xy_datas_comb[!, i] for i in 2:size(xy_datas_comb, 2)]

    if length(griditem.channel_range_selected) != 4
        griditem.channel_range_selected = [0., 1., 0., 1.]
    end
    x_inverted = (griditem.channel_range_selected[3] > griditem.channel_range_selected[4]) ? true : false
    y_inverted = (griditem.channel_range_selected[1] > griditem.channel_range_selected[2]) ? true : false
    if x_inverted
        reverse!(x_data)
        x_data .*= -1.
    end
    for y_data in y_datas
        if x_inverted
            reverse!(y_data)
        end
        if y_inverted
            y_data .*= -1.
        end
    end

    type = "line"  # let's always do a line for now
    spectrum_data = Dict{String,Any}("x_data" => x_data, "y_datas" => y_datas, "colors" => colors, "type" => type, "x_inverted" => x_inverted, "y_inverted" => y_inverted)
    return spectrum_data
end


"""
    function save_spectrum_svg(filename::AbstractString, x_datas::AbstractVector{<:AbstractVector}, y_datas::AbstractVector{<:AbstractVector},
        colors::AbstractVector{<:AbstractString}; range_selected::Vector{Float64}=[0.,1.,0.,1.])::Vector{Float64}

Saves a graph of multiple curves to a SVG file (`filename`). Each curve is represented by an element in the vectors `x_datas`, `y_datas` and `colors`.
A relative zoom can be specified in a four-element vector `range_selected`.
Returns the ranges of y_datas and x_data.
"""
function save_spectrum_svg(filename::AbstractString, xy_datas::AbstractVector{DataFrame}, colors::AbstractVector{<:AbstractString}; range_selected::Vector{Float64}=[0.,1.,0.,1.])::Vector{Float64}

    @assert length(xy_datas) == length(colors)
    if length(range_selected) != 4
        range_selected = [0., 1., 0., 1.]
    end
    yxranges = Float64[]

    open(filename, "w") do f
        write(f, svg_header)

        # get minimum and maximum values for all data
        extrema_x = extrema.([xy_data[!, 1] for xy_data in xy_datas if size(xy_data, 1) > 0])
        extrema_y = extrema.([xy_data[!, 2] for xy_data in xy_datas if size(xy_data, 1) > 0])

        min_x = 0.
        max_x = 0.
        min_y = 0.
        max_y = 0.
        if length(extrema_x) > 0
            min_x = minimum(first.(extrema_x))
            max_x = maximum(last.(extrema_x))
        end
        if length(extrema_y) > 0
            min_y = minimum(first.(extrema_y))
            max_y = maximum(last.(extrema_y))
        end

        # it causes problems if the span is zero, so we expand the range if that happens
        if min_x ≈ max_x
            min_x, max_x = expand_range(min_x, max_x)
        end
        if min_y ≈ max_y
            min_y, max_y = expand_range(min_y, max_y)
        end

        yxranges = [min_y, max_y, min_x, max_x]

        # absolute selected range-span in x and y, should always be != 0
        yxranges_selected = [
            yxranges[1] + (yxranges[2] - yxranges[1]) * range_selected[1],
            yxranges[1] + (yxranges[2] - yxranges[1]) * range_selected[2],
            yxranges[3] + (yxranges[4] - yxranges[3]) * range_selected[3],
            yxranges[3] + (yxranges[4] - yxranges[3]) * range_selected[4]
        ]

        x_delta = yxranges_selected[4] - yxranges_selected[3]
        y_delta = yxranges_selected[2] - yxranges_selected[1]
        if abs(x_delta) < 1e-32
            s = (x_delta < 0.) ? -1. : 1.
            x_delta = s * 1e-32
        end
        if abs(y_delta) < 1e-32
            s = (y_delta < 0.) ? -1. : 1.
            y_delta = s * 1e-32
        end
        x_scale = 100. / x_delta
        y_scale = 100. / y_delta

        @views for (xy_data, color) in zip(xy_datas, colors)
            x_data = xy_data[!, 1]
            y_data = xy_data[!, 2]
            x_data_plot = @. round((x_data - yxranges_selected[3]) * x_scale, digits=2)
            y_data_plot = @. round(100 - ((y_data - yxranges_selected[1]) * y_scale), digits=2)

            points = ""
            @views @inbounds for j in 1:length(x_data_plot)
                points *= "$(x_data_plot[j]),$(y_data_plot[j]) "
            end
            write(f, polyline_header_1 * color * polyline_header_2 * points * polyline_footer)
        end
        write(f, svg_footer)
    end
    return yxranges
end


"""Creates and saves a svg image for channel_name vs channel2_name.
The "filename_display" field of the SpmGridItem is updated (to the svg filename without the directory prefix)
if use_existing is true, then an updated image will only be generated if the last-modified date of the image does not correspon to the one save in the db."""
function create_spectrum!(griditem::SpmGridItem, spectrum::SpmSpectrum; base_dir::String="", use_existing::Bool=false)
    if use_existing && griditem_cache_up_to_date(griditem, base_dir)
        return nothing  # image exists, nothing to do
    end

    # load spectrum
    xy_datas, colors = get_spectrum_data(griditem, spectrum, sort_x_any=true)  # sort x_values (asc or desc is ok), so that we get a nice line plot
    griditem.points = size(xy_datas[1], 1)

    filename_display = "$(griditem.filename_original[1:end-4])_$(griditem.virtual_copy).svg"
    f = joinpath(base_dir, filename_display)
    yxranges = save_spectrum_svg(f, xy_datas, colors, range_selected=griditem.channel_range_selected)

    griditem.channel_range = yxranges

    griditem.filename_display = filename_display
    griditem.filename_display_last_modified = unix2datetime(mtime(f))
    return nothing
end


"""Parses a spectrum file and creates the preview in the cache directory if necessary."""
function parse_spectrum!(images_parsed::Dict{String, SpmGridItem}, virtual_copies_dict::Dict{String,Array{SpmGridItem}},
    images_parsed_new::Vector{String}, only_new::Bool,
    dir_cache::String, datafile::String, id::String, filename_original::String, created::DateTime, last_modified::DateTime)::Nothing

    # spectrum = load_spectrum_cache(datafile)
    spectrum = load_spectrum(datafile, index_column=true, index_column_type=Float64)  # we do not use the cache here

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
        else
            spectrum.position[1] = 0.
        end
    end
    if isnan(spectrum.position[2])
        if "Y" in spectrum.channel_names
            spectrum.position[2] = spectrum.data[1, "Y"]
        else
            spectrum.position[2] = 0.
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