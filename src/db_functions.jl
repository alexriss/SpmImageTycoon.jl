"""load data from saved file"""
function load_all(dir_data::String, w::Union{Window,Nothing})::Tuple{Dict{String, SpmGridItem}, Dict{String, Vector{String}}}
    griditems = Dict{String, SpmGridItem}()
    channel_names_list = Dict{String, Vector{String}}()

    f = joinpath(get_dir_cache(dir_data), filename_db)
    if isfile(f)
        loaded = JLD2.load(f)
        if haskey(loaded, "griditems")
            griditems_save = loaded["griditems"]
        elseif haskey(loaded, "images_parsed_save")  # legacy, for versions before 0.3.0
            griditems_save = loaded["images_parsed_save"]
        else
            println("Warning: Empty database found.")  # this should not happen
            return griditems, channel_names_list
        end

        if haskey(loaded, "channel_names_list")
            channel_names_list = loaded["channel_names_list"]
        end

        if typeof(griditems_save) == JLD2.SerializedDict
            griditems_save = griditems_save.kvvec  # that is how it is reconstructed by JLD2
        end

        if length(griditems_save) == 0
            return griditems, channel_names_list
        end

        first_value = first(values(griditems_save))
        t_save = typeof(first_value)
        if t_save <: Pair # JLD2 apparently reconstructs an array of pairs{id, SpmGridItem}
            t_save = typeof(first_value[2])
            first_value = first_value[2]
        end

        if t_save != SpmGridItem  # there was a change in the struct specification, lets try to copy field by field
            log("Old database detected. Converting... ", w, new_line=false)

            # fieldnames_save = fieldnames(t_save)
            fieldnames_save = propertynames(first_value)  # this seems to be the way for the new JLD2 version (5.10)
            fieldnames_common = filter(x -> x in fieldnames_save, fieldnames(SpmGridItem))
            
            for pair in griditems_save  # JLD2 apparently reconstructs an array of pairs{id, SpmGridItem}
                id = pair[1]
                griditem = pair[2]
                griditems[id] = SpmGridItem()
                for f in fieldnames_common
                    val = getproperty(griditem, f)  # in JLD2 v5.10, the fields are called properties
                    if fieldtype(SpmGridItem, f) != typeof(val)  # this can happen; we changed "scan_direction" from bool to int in v129
                        val = convert(fieldtype(SpmGridItem, f), val)
                    end
                    setfield!(griditems[id], f, val)
                end
            end

            log("ok.", w)
        else
            griditems = griditems_save
        end
    end

    return griditems, channel_names_list
end


"""saves the griditems dictionary to file"""
function save_all(dir_data::String, griditems::Dict{String, SpmGridItem}, channel_names_list::Dict{String,Vector{String}})::Nothing
    f = joinpath(get_dir_cache(dir_data), filename_db)
    JLD2.save(f, Dict(
        "griditems" => griditems,
        "channel_names_list" => channel_names_list
    ))

    backup_database(dir_data)

    return nothing
end


"""Creates/overwrites backups of the database file"""
function backup_database(dir_data::String)::Nothing
    f_current = joinpath(get_dir_cache(dir_data), filename_db)
    mtime_current = mtime(f_current)

    for (num,hours) in enumerate(backup_scheme_hours)
        fname = replace(filename_db_backup, "{{num}}" => "$num")
        f = joinpath(get_dir_cache(dir_data), fname)
        if isfile(f)
            diff = (mtime_current - mtime(f)) / 3600.
            if diff > hours
                cp(f_current, f, force=true)
            end
        else
            cp(f_current, f)
        end
    end

    return nothing
end