using Mustache
using Printf
using ZipFile


const dir_media_odp = "media/"  # media files directory in the odp zip file 

const odp_num_per_row = 3  # number of images per row
const odp_num_per_col = 2  # number of images per column
const odp_width_image = 7.3  # width of each image (cm)
const odp_positions_image = [
    [0.85, 3.0], [10.35,3.0], [19.85,3.0],
    [0.85, 12.0], [10.35,12.0], [19.85,12.0],
]
const odp_spacer = 0.08
const odp_spacer_scalebar = 0.18
const odp_spacer_scalebar_label = 0.34
const odp_lineheight = 0.4

const odp_max_comment_lines = 4  # maximum number of comment lines, otherwise everything is output wihtout linebreaks

const odp_scalebar_width = 0.26  # approximate target scalebar width as a fraction of the image (will be adjusted so that we have nicer numbers)

const unit_prefixes = ["E", "P", "T", "G", "M", "k", "", "m", "µ", "n", "p", "f", "a"]
const unit_factors = [1.0e18, 1.0e15, 1.0e12, 1.0e9, 1.0e6, 1.0e3, 1.0, 1.0e-3, 1.0e-6, 1.0e-9, 1.0e-12, 1.0e-15, 1.0e-18]


"""determines the best unit prefix for the given value"""
function get_factor_prefix(number::Real)::Tuple{Float64, String}
    # The format function of the Formatting library supports some of the SI prefixes, but
    # 1. only down to pico, and 2. it will not convert 0.05 as 50.0m (instead as 0.0)

    unit_prefix = unit_prefixes[end]
    unit_factor = unit_factors[end]

    number_abs = abs(number)
    for (i, factor) in enumerate(unit_factors)
        if number_abs >= factor
            unit_prefix = unit_prefixes[i]
            unit_factor = factor
            break
        end
    end
    return unit_factor, unit_prefix
end


"""formats a number to a notation that uses SI prefixes"""
function format_with_prefix(number::Real; delimiter::String="")::String
    if number == 0
        return "0$delimiter"
    end

    unit_factor, unit_prefix = get_factor_prefix(number)

    number = number / unit_factor
    return @sprintf("%0.1f", number) * "$delimiter$unit_prefix"
end


"""formats a vector of numbers to a notation that uses SI prefixes"""
function format_with_prefix(numbers::AbstractVector{<:Real})::Tuple{Vector{String}, String, Float64}
    max_number = maximum(abs.(numbers))
    unit_factor, unit_prefix = get_factor_prefix(max_number)

    formatted = map(numbers) do number
        if number == 0
            return "0"
        end
        number = number / unit_factor
        return @sprintf("%0.1f", number)
    end
    return formatted, unit_prefix, unit_factor
end


"""Traverses a directory and all its subdirectories and populates the files-array with paths relative to current_subdir"""
function readdir_recursive!(files::Vector{<:AbstractString}, dir::AbstractString, current_subdir::AbstractString)
    for f in readdir(dir, join=false)
        f_full = joinpath(dir, f)
        if isfile(f_full)
            push!(files, joinpath(current_subdir, f))
        elseif isdir(f_full)
            readdir_recursive!(files, joinpath(dir, f), joinpath(current_subdir, f))
        end
    end
    return nothing
end


"""reads comments into an array"""
function get_comment_lines(comment::String)::Vector{String}
    """reads comments from an SPM image"""
    comment_lines_raw = split(comment, "\n")
    comment_lines = Vector{String}(undef, 0)
    for c in comment_lines_raw
        c = strip(c)
        if length(c) == 0
            continue
        end
        skip = false
        for igc in odp_ignore_comment_lines
            if startswith(c, igc)
                skip = true
                break
            end
        end
        if !skip
            push!(comment_lines, c)
        end
    end
    return comment_lines
end


"""returns the newly added comment lines, i.e. the difference between comment_lines and comment_lines_old"""
function get_comment_lines_difference(comment_lines::Vector{String}, comment_lines_old::Vector{String})::Vector{String}
    if comment_lines == comment_lines_old  # skip title if it is the same preparation as before
        return Vector{String}(undef, 0)
    elseif length(comment_lines_old) == 0  # everything is new
        return comment_lines
    end

    result = Vector{String}(undef, 0)
    if length(comment_lines) >= length(comment_lines_old) && comment_lines_old == comment_lines[1:length(comment_lines_old)] # likely the same preparation
        push!(result, "...")
    else
        return comment_lines
    end

    for (i, c) in enumerate(comment_lines)
        if i <= length(comment_lines_old) && c == comment_lines_old[i]
            continue
        end
        push!(result, c)
    end
    return result
end


"""returns dimensions of scalebar (in the same units as image_width)"""
function get_scalebar_width(image_width::AbstractFloat)::Float64
    scalebar_width = image_width * odp_scalebar_width

    # use powers of 2 for scalebar
    l = log2(scalebar_width)
    scalebar_width = 2^floor(l)

    if scalebar_width >= 8
        scalebar_width = round(scalebar_width, digits=-1)
    elseif scalebar_width < 0.5
        scalebar_width = 0.5
    end
        
    return scalebar_width
end


"""returns the formatted sample bias and feedback parameters"""
function get_image_parameters(griditem::SpmGridItem)::Tuple{String,String}
    if isnan(griditem.bias)
        r_bias = "-"
    elseif griditem.bias == 0
        r_bias = "0"
    else
        # r_bias = format(bias, precision=1, autoscale=:metric)
        r_bias = format_with_prefix(griditem.bias)
    end
    r_bias *= "V"

    if griditem.z_feedback
        r_feedback = format_with_prefix(griditem.z_feedback_setpoint) * griditem.z_feedback_setpoint_unit
    else
        r_feedback = "z=const"
    end

    return r_bias, r_feedback
end


"""Saves an OpenOffice Document presentation"""
function export_odp(ids::Vector{String}, dir_data::String, griditems::Dict{String, SpmGridItem}, filename_export::String)
    dir_cache = get_dir_cache(dir_data)
    
    dict_template = Dict{String,Any}()
    dict_template["title"] = splitpath(dir_data)[end]
    dict_template["date"] = Dates.format(Dates.now(), "dd u yyyy, HH:MM")
    
    if isfile(filename_export)
        rm(filename_export)
    end
    zipfile = ZipFile.Writer(filename_export)
    template_files = Vector{String}(undef, 0)
    readdir_recursive!(template_files, dir_template_odp, "")
    
    # add all images to the zip file, also get channel data, keywords, etc.
    keywords = Set{String}()
    dict_template["pages"] = Vector{Dict{String, Any}}(undef, 0)
    comment_lines_old = Vector{String}(undef, 0)
    count = 1
    for id in ids
        dict_image = Dict{String, Any}()
        griditem = griditems[id]
        
        # get comments
        # for now, we only use the comments in the images
        if griditem.type == SpmGridImage
            comment_lines = get_comment_lines(griditem.comment)
            if comment_lines != comment_lines_old
                count = 1  # will force new page
            end
        else
            comment_lines = [""]
        end

        if count % (odp_num_per_row * odp_num_per_col) == 1  # new page
            push!(dict_template["pages"], Dict{String, Any}())
            dict_template["pages"][end]["images"] = Vector{Dict{String, Any}}(undef, 0)
            comment_lines_page = get_comment_lines_difference(comment_lines, comment_lines_old)
            if length(comment_lines_page) > odp_max_comment_lines
                comment_lines_page = [join(comment_lines_page, "; ")]
            end
            dict_template["pages"][end]["comments"] = comment_lines_page
            dict_template["pages"][end]["n"] = length(dict_template["pages"])
            count = 1
        end
        
        x, y = odp_positions_image[count]
        dict_image["fullwidth"] = odp_width_image  # needed for some elements
        dict_image["halfwidth"] = odp_width_image / 2  # needed for some elements

        if griditem.type == SpmGridImage
            dict_image["scalebar_show"] = true
            width, height = griditem.scansize
        else
            dict_image["scalebar_show"] = false
            width, height = 1., 1.
        end

        # adjust height for non-square images
        dict_image["width"] = min(odp_width_image, width/height * odp_width_image)
        dict_image["height"] = dict_image["width"] * height/width
        dict_image["image_x"] = x + (odp_width_image - dict_image["width"]) / 2  # center horizontally
        dict_image["image_y"] = y + (odp_width_image - dict_image["height"]) / 2  # center vertically

        if griditem.type == SpmGridImage
            # scalebar size
            scalebar_width_nm = get_scalebar_width(width)
            if scalebar_width_nm == round(scalebar_width_nm, digits=0)
                dict_image["scalebar_width_nm"] = Int(scalebar_width_nm)
            else
                dict_image["scalebar_width_nm"] = round(scalebar_width_nm, digits=1)
            end
            dict_image["scalebar_unit"] = griditem.scansize_unit
            dict_image["scalebar_width"] = dict_image["scalebar_width_nm"] * dict_image["width"] / width
            dict_image["scalebar_x1"] = x + odp_width_image - dict_image["scalebar_width"]
            dict_image["scalebar_x2"] = x + odp_width_image
            dict_image["scalebar_y"] = y + odp_width_image + odp_spacer_scalebar   # it is a line - so just one y coordinate needed
            
            # scalebar label
            dict_image["scalebar_label_x"] = x + odp_width_image / 2
            dict_image["scalebar_label_y"] = y + odp_width_image + odp_spacer_scalebar_label
        end
      
        # captions and image parameters
        dict_image["filename_x"] = x
        dict_image["filename_y"] = y + odp_width_image + odp_spacer
        
        dict_image["channel_x"] = x
        dict_image["channel_y"] = y + odp_width_image + 2 * odp_spacer + odp_lineheight

        if haskey(odp_channel_names_short, griditem.channel_name)
            dict_image["channel_name"] = odp_channel_names_short[griditem.channel_name]
        else
            dict_image["channel_name"] = griditem.channel_name
        end
        dict_image["bias"], dict_image["feedback"] = get_image_parameters(griditem)
        if dict_image["bias"] == "-V"
            dict_image["bias"] = ""
        end

        filename_display = griditem.filename_display
        filename_odp = joinpath(dir_media_odp, filename_display)
        filename_odp = replace(filename_odp, "\\" => "/")  # we seem to need forward-slashes for the ZipFile
        union!(keywords, griditem.keywords)
        dict_image["filename_odp"] = filename_odp
        dict_image["filename"] = griditem.filename_original
        
        # save all image data to our main dictionary (will be used later for mustache rendering)
        push!(dict_template["pages"][end]["images"], dict_image)

        # save png/svg to zip files
        f = ZipFile.addfile(zipfile, filename_odp; method=ZipFile.Deflate)
        if griditem.type == SpmGridImage
            write(f, read(joinpath(dir_cache, filename_display), String))
        else  # we adapt the svg file for spectra
            svg_str = read(joinpath(dir_cache, filename_display), String)
            channel_ranges = copy(griditem.channel_range)
            if length(griditem.channel_range_selected) == length(channel_ranges)
                channel_ranges[1] = griditem.channel_range[1] + (channel_ranges[2] - channel_ranges[1]) * griditem.channel_range_selected[1]
                channel_ranges[2] = griditem.channel_range[1] + (channel_ranges[2] - channel_ranges[1]) * griditem.channel_range_selected[2]
                channel_ranges[3] = griditem.channel_range[3] + (channel_ranges[4] - channel_ranges[3]) * griditem.channel_range_selected[3]
                channel_ranges[4] = griditem.channel_range[3] + (channel_ranges[4] - channel_ranges[3]) * griditem.channel_range_selected[4]
            end
            footer = svg_footer_export  # we need to a few replacements first
            x_channel_range_strs, x_unit_prefix, x_unit_factor = format_with_prefix(channel_ranges[3:4])
            x_axis_label = griditem.channel2_name * " / " * x_unit_prefix * griditem.channel2_unit
            footer = replace(footer, "{{ x_axis_label }}" => x_axis_label, count=1)
            footer = replace(footer, "{{ x_axis_min }}" => x_channel_range_strs[1], count=1)
            footer = replace(footer, "{{ x_axis_max }}" => x_channel_range_strs[2], count=1)
            y_channel_range_strs, y_unit_prefix, y_unit_factor = format_with_prefix(channel_ranges[1:2])
            y_axis_label = griditem.channel_name * " / " * y_unit_prefix * griditem.channel_unit
            footer = replace(footer, "{{ y_axis_label }}" => y_axis_label, count=1)
            footer = replace(footer, "{{ y_axis_min }}" => y_channel_range_strs[1], count=1)
            footer = replace(footer, "{{ y_axis_max }}" => y_channel_range_strs[2], count=1)

            svg_str = replace(svg_str, svg_footer => footer, count=1)
            svg_str = replace(svg_str, svg_header => svg_header_export, count=1)
            write(f, svg_str)
        end
        
        comment_lines_old = comment_lines
        count += 1
    end
    
    # add xml files etc (for some we use a mustache rendering)
    dict_template["keywords"] = join(keywords, ", ")
    for template_file in template_files
        f_contents = read(joinpath(dir_template_odp, template_file), String)
        if endswith(template_file, ".tpl")
            f_contents = Mustache.render(f_contents, dict_template)
            template_file = template_file[1:end-4]
        end
        template_file = replace(template_file, "\\" => "/")  # we seem to need forward-slashes for the ZipFile
        f = ZipFile.addfile(zipfile, template_file; method=ZipFile.Deflate)
        write(f, f_contents)
    end

    close(zipfile)

    return dict_template
end