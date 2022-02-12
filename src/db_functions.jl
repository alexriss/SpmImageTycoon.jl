"""load data from saved file"""
function load_all(dir_data::String, w::Union{Window,Nothing})::Dict{String, SpmGridItem}
    griditems = Dict{String, SpmGridItem}()
    
    f = joinpath(get_dir_cache(dir_data), filename_db)
    if isfile(f)
        loaded = JLD2.load(f)
        if haskey(loaded, "griditems")
            griditems_save = loaded["griditems"]
        elseif haskey(loaded, "images_parsed_save")  # legacy, for versions before 0.3.0
            griditems_save = loaded["images_parsed_save"]
        else
            println("Warning: Empty database found.")  # this should not happen
            return griditems
        end

        if length(griditems_save) == 0
            return griditems
        end

        first_value = first(values(griditems_save))
        t_save = typeof(first_value)
        if t_save <: Pair # JLD2 apparently reconstructs an array of pairs{id, SpmGridItem}
            t_save = typeof(first_value[2])
        end

        if t_save != SpmGridItem  # there was a change in the struct specification, lets try to copy field by field
            log("Old database detected. Converting... ", w, new_line=false)

            fieldnames_save = fieldnames(t_save)
            fieldnames_common = filter(x -> x in fieldnames_save, fieldnames(SpmGridItem))

            for pair in griditems_save  # JLD2 apparently reconstructs an array of pairs{id, SpmGridItem}
                id = pair[1]
                griditem = pair[2]
                griditems[id] = SpmGridItem()
                for f in fieldnames_common
                    val = getfield(griditem, f)
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

    return griditems
end


"""saves the griditems dictionary to file"""
function save_all(dir_data::String, griditems::Dict{String, SpmGridItem})::Nothing
    f = joinpath(get_dir_cache(dir_data), filename_db)
    JLD2.save(f, Dict("griditems" => griditems))

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