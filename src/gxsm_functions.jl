"""Returns true if the griditem is a GXSM image file."""
function is_gxsm_image(griditem::SpmGridItem)::Bool
    return endswith(griditem.filename_original, extension_image_gxsm)
end


"""Returns true if the filename is a GXSM image file."""
function is_gxsm_image(filename::String)::Bool
    return endswith(filename, extension_image_gxsm)
end


"""Returns true if the griditem is a GXSM spectrum file."""
function is_gxsm_spectrum(griditem::SpmGridItem)::Bool
    return endswith(griditem.filename_original, extension_spectrum_gxsm)
end


"""Returns true if the filename is a GXSM spectrum file."""
function is_gxsm_spectrum(filename::String)::Bool
    return endswith(filename, extension_spectrum_gxsm)
end


"""Sets the filename_original field for `griditem` according to the channel. This is needed because GXSM files have one file for each channel."""
function change_gxsm_griditem_filename_original!(griditem::SpmGridItem, channel::String)::Nothing
    if is_gxsm_image(griditem) && haskey(channel_names_files, griditem.id)
        if haskey(channel_names_files[griditem.id], channel)
            griditem.filename_original = channel_names_files[griditem.id][channel]
        elseif haskey(channel_names_files[griditem.id], image_channel_name_fwd(channel))
            griditem.filename_original = channel_names_files[griditem.id][image_channel_name_fwd(channel)]
        elseif haskey(channel_names_files[griditem.id], image_channel_name_bwd(channel))
            griditem.filename_original = channel_names_files[griditem.id][image_channel_name_bwd(channel)]
        end
    end
    return nothing
end

"""Get available channel names for GXSM files (needed if only one file is loaded)."""
function get_gxsm_channel_names(griditem::SpmGridItem)::Vector{String}
    id = base_filename(griditem.filename_original)
    !haskey(channel_names_files, id) && return String[]  # should not happen, though
    return unique(image_channel_name_fwd.(keys(channel_names_files[id])))
end