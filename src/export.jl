using Formatting
using Mustache
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

const odp_format_number = generate_formatter("%0.1f")   # format function
const unit_prefixes = ["E", "P", "T", "G", "M", "k", "", "m", "µ", "n", "p", "f", "a"]
const unit_factors = [10^18, 10^15, 10^12, 10^9, 10^6, 10^3, 1, 10^-3, 10^-6, 10^-9, 10^-12, 10^-15, 10^-18]


"""formats a number to a notation that uses SI prefixes"""
function format_with_prefix(number::Number, delimiter::String="")::String
    # The format function of the Formatting library supports some of the SI prefixes, but
    # 1. only down to pico, and 2. it will not convert 0.05 as 50.0m (instead as 0.0)
    if number == 0
        return "0$delimiter"
    end

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
    number = number / unit_factor
    return odp_format_number(number) * "$delimiter$unit_prefix"
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
    l = log(2, scalebar_width)
    scalebar_width = 2^floor(l)

    if scalebar_width >= 8
        scalebar_width = round(scalebar_width, digits=-1)
    elseif scalebar_width < 0.5
        scalebar_width = 0.5
    end
        
    return scalebar_width
end


"""returns the formatted sample bias and feedback parameters"""
function get_image_parameters(id::String, dir_data::String, images_parsed::Dict{String,SpmImageGridItem})::Tuple{String,String}
    # TODO: maybe the header info for bias and feedback should be read into the SpmImageGridItem already

    header = get_image_header(id, dir_data, images_parsed)
    bias = parse(Float64, header["Bias"])
    if bias == 0
        r_bias = "0"
    else
        # r_bias = format(bias, precision=1, autoscale=:metric)
        r_bias = format_with_prefix(bias)
    end
    r_bias *= "V"

    if header["Z-Controller>Controller status"] == "ON"
        feedback = parse(Float64, header["Z-Controller>Setpoint"])
        feedback_unit = header["Z-Controller>Setpoint unit"]
        r_feedback = format_with_prefix(feedback) * feedback_unit
    else
        r_feedback = "z=const"
    end

    return r_bias, r_feedback
end


"""Saves an OpenOffice Document presentation"""
function export_odp(ids::Vector{String}, dir_data::String, images_parsed::Dict{String, SpmImageGridItem}, filename_export::String)
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
        
        # get comments
        comment_lines = get_comment_lines(images_parsed[id].comment)
        if comment_lines != comment_lines_old
            count = 1  # will force new page
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

        # adjust height for non-square images
        width, height = images_parsed[id].scansize
        dict_image["width"] = min(odp_width_image, width/height * odp_width_image)
        dict_image["height"] = dict_image["width"] * height/width
        dict_image["image_x"] = x + (odp_width_image - dict_image["width"]) / 2  # center horizontally
        dict_image["image_y"] = y + (odp_width_image - dict_image["height"]) /2  # center vertically
        
        # scalebar size
        scalebar_width_nm = get_scalebar_width(width)
        if scalebar_width_nm == round(scalebar_width_nm, digits=0)
            dict_image["scalebar_width_nm"] = Int(scalebar_width_nm)
        else
            dict_image["scalebar_width_nm"] = round(scalebar_width_nm, digits=1)
        end
        dict_image["scalebar_unit"] = images_parsed[id].scansize_unit
        dict_image["scalebar_width"] = dict_image["scalebar_width_nm"] * dict_image["width"] / width
        dict_image["scalebar_x1"] = x + odp_width_image - dict_image["scalebar_width"]
        dict_image["scalebar_x2"] = x + odp_width_image
        dict_image["scalebar_y"] = y + odp_width_image + odp_spacer_scalebar   # it is a line - so just one y coordinate needed
        
        # captions and image parameters
        dict_image["scalebar_label_x"] = x + odp_width_image / 2
        dict_image["scalebar_label_y"] = y + odp_width_image + odp_spacer_scalebar_label
        
        dict_image["filename_x"] = x
        dict_image["filename_y"] = y + odp_width_image + odp_spacer
        
        dict_image["channel_x"] = x
        dict_image["channel_y"] = y + odp_width_image + 2 * odp_spacer + odp_lineheight

        if haskey(odp_channel_names_short, images_parsed[id].channel_name)
            dict_image["channel_name"] = odp_channel_names_short[images_parsed[id].channel_name]
        else
            dict_image["channel_name"] = images_parsed[id].channel_name
        end
        dict_image["bias"], dict_image["feedback"] = get_image_parameters(id, dir_data, images_parsed)

        filename_display = images_parsed[id].filename_display
        filename_odp = joinpath(dir_media_odp, filename_display)
        filename_odp = replace(filename_odp, "\\" => "/")  # we seem to need forward-slashes for the ZipFile
        union!(keywords, images_parsed[id].keywords)
        dict_image["filename_odp"] = filename_odp
        dict_image["filename"] = images_parsed[id].filename_original
        
        # save all image data to our main dictionary (will be used later for mustache rendering)
        push!(dict_template["pages"][end]["images"], dict_image)

        # save png to zip files
        f = ZipFile.addfile(zipfile, filename_odp; method=ZipFile.Deflate)
        write(f, read(joinpath(dir_cache, filename_display), String))
        
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