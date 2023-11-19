"""Returns true if the griditem is a GSXM file."""
function is_gsxm(griditem::SpmGridItem)::Bool
    return endswith(griditem.filename_original, extension_image_gsxm)
end


"""Returns true if the filename is a GSXM file."""
function is_gsxm(filename::String)::Bool
    return endswith(filename, extension_image_gsxm)
end


"""Sets the filename_original field for `griditem` according to the channel. This is needed because GSXM files have one file for each channel."""
function change_gsxm_griditem_filename_original!(griditem::SpmGridItem, channel::String)::Nothing
    if is_gsxm(griditem) && haskey(channel_names_files, griditem.id)
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

"""Get available channel names for GSXM files (needed if only one file is loaded)."""
function get_gsxm_channel_names(griditem::SpmGridItem)::Vector{String}
    id = base_filename(griditem.filename_original)
    !haskey(channel_names_files, id) && return String[]  # should not happen, though
    return unique(image_channel_name_fwd.(keys(channel_names_files[id])))
end