"""sets the julia handlers that are triggered by javascript events"""
function set_event_handlers(w::Window, dir_data::String, griditems::Dict{String,SpmGridItem})
    # this function is called when a new directory is loaded,
    # so the griditems might change when the dir is parsed, thus we set `griditems_last_changed`
    global griditems_last_changed = time()

    l = ReentrantLock()  # not sure if it is necessary to do it here, but it shoul be safer this way
    handle(w, "grid_item") do args  # cycle through scan channels
        what = args[1]
        ids = string.(args[2])  # for some reason its type is "Any" and not String
        if what == "get_info"
            id = ids[1]
            zoomview = args[3]
            # get header data
            try
                image_header, extra_info = get_griditem_header(griditems[id], dir_data)
                k = replace.(collect(keys(image_header)), ">" => "><wbr>")  # replace for for word wrap in tables
                v = replace.(collect(values(image_header)), "\n" => "<br />") 
                v = utf8ify.(v)
                image_header_json = JSON.json(vcat(reshape(k, 1, :), reshape(v, 1, :)))
                json_compressed = transcode(GzipCompressor, image_header_json)
                @js_ w show_info($id, $json_compressed, $extra_info);
                if zoomview
                    if griditems[id].type == SpmGridImage
                        width, counts = get_histogram(griditems[id], dir_data)
                        @js_ w show_histogram($id, $width, $counts)
                    else
                        # get 2d data for spectrum
                        spectrum_data = get_spectrum_data_dict(griditems[id], dir_data)
                        json_compressed = transcode(GzipCompressor, JSON.json(spectrum_data))
                        @js_ w show_spectrum($id, $json_compressed)
                    end
                end
            catch e
                error(e, w)
            end
        elseif what[1:5] == "next_"
            global griditems_last_changed = time()

            lock(l)
            jump = args[3]
            full_resolution = args[4]
            try
                change_griditem!(griditems, ids, dir_data, what[6:end], jump, full_resolution)
                griditems_sub = get_subset(griditems, ids)
                json_compressed = transcode(GzipCompressor, JSON.json(griditems_sub))
                @js_ w update_images($json_compressed);
            catch e
                error(e, w)
            finally
                unlock(l)
                global griditems_last_changed = time()
            end
        elseif what[1:4] == "set_"
            if what[5:end] == "rating"
                lock(l)
                rating = args[3]
                try
                    for id in ids
                        griditems[id].rating = rating
                    end
                    griditems_sub = get_subset(griditems, ids)
                    json_compressed = transcode(GzipCompressor, JSON.json(griditems_sub))
                    @js_ w update_images($json_compressed);
                catch e
                    error(e, w)
                finally
                    unlock(l)
                    global griditems_last_changed = time()
                end
            elseif what[5:end] == "keywords"
                lock(l)
                mode = args[3]
                keywords = string.(args[4])
                if length(keywords) == 0  # for whatever reason an empty array does not get converted to a stirng type empty array
                    keywords = String[]
                end
                try
                    set_keywords!(ids, dir_data, griditems, mode, keywords)
                    griditems_sub = get_subset(griditems, ids)
                    json_compressed = transcode(GzipCompressor, JSON.json(griditems_sub))
                    @js_ w update_images($json_compressed);
                catch e
                    error(e, w)
                finally
                    unlock(l)
                    global griditems_last_changed = time()
                end
            elseif what[5:end] == "range_selected"
                lock(l)
                range_selected = float.(args[3])
                full_resolution = args[4]
                try
                    set_range_selected!(ids, dir_data, griditems, range_selected, full_resolution)
                    griditems_sub = get_subset(griditems, ids)
                    json_compressed = transcode(GzipCompressor, JSON.json(griditems_sub))
                    @js_ w update_images($json_compressed);
                catch e
                    error(e, w, false)  # do not show modal-dialog for user if anything goes wrong
                finally
                    unlock(l)
                    global griditems_last_changed = time()
                end
            elseif what[5:end] == "range_selected_spectrum"
                lock(l)
                range_selected = float.(args[3])
                try
                    set_range_selected_spectrum!(ids, dir_data, griditems, range_selected)
                    griditems_sub = get_subset(griditems, ids)
                    json_compressed = transcode(GzipCompressor, JSON.json(griditems_sub))
                    @js_ w update_images($json_compressed);
                catch e
                    error(e, w, false)  # do not show modal-dialog for user if anything goes wrong
                finally
                    unlock(l)
                    global griditems_last_changed = time()
                end
            end
        elseif what == "get_line_profile"
            lock(l)  # might not be necessary here, as it is just a read operation - but griditems might change, so let's keep it
            id = ids[1]
            try
                start_point = float.(args[3])
                end_point = float.(args[4])
                width = float(args[5])
                # start_point_value and end_point_value is just the point (width does not affect it)
                coords, distances, values, start_point_value, end_point_value = get_line_profile(id, dir_data, griditems, start_point, end_point, width)
                @js_ w show_line_profile($id, $distances, $values, $start_point_value, $end_point_value)
            catch e
                error(e, w, false)  # do not show modal-dialog for user if anything goes wrong
            finally
                unlock(l)
            end
        elseif what == "reset"
            lock(l)
            full_resolution = args[3]
            try
                reset_griditem!(griditems, ids, dir_data, full_resolution)
                griditems_sub = get_subset(griditems, ids)
                json_compressed = transcode(GzipCompressor, JSON.json(griditems_sub))
                @js_ w update_images($json_compressed);
            catch e
                error(e, w)
            finally
                unlock(l)
                global griditems_last_changed = time()
            end
        elseif what == "paste_params"
            lock(l)
            id_from = args[3]
            full_resolution = args[4]
            try
                paste_params!(griditems, ids, id_from, dir_data, full_resolution)
                griditems_sub = get_subset(griditems, ids)
                json_compressed = transcode(GzipCompressor, JSON.json(griditems_sub))
                @js_ w update_images($json_compressed);
            catch e
                error(e, w)
            finally
                unlock(l)
                global griditems_last_changed = time()
            end
        elseif what == "virtual_copy"
            lock(l)
            mode = args[3]
            try
                if mode =="create"
                    updated_virtual_copy_is = Dict{String, Int}()  # save updated virtual copy values (so that we keep js and julia in sync - might be important for js-sorting)
                    ids_new = Array{String}(undef, 0)
                    for id in ids
                        id_original = griditems[id].filename_original
                        virtual_copies = get_virtual_copies(griditems, id_original)
                        new_i = update_virtual_copies_order!(virtual_copies, id) 
                        id_new = get_new_id(griditems, id_original)
                        virtual_copy_new = deepcopy(griditems[id])
                        virtual_copy_new.id = id_new
                        virtual_copy_new.virtual_copy = new_i
                        griditems[id_new] = virtual_copy_new

                        push!(ids_new, id_new)
                        for virtual_copy in virtual_copies
                            updated_virtual_copy_is[virtual_copy.id] = virtual_copy.virtual_copy
                        end
                    end

                    griditems_sub = get_subset(griditems, ids_new)
                    @js_ w insert_images($griditems_sub, $ids)  # insert images after positions of ids
                elseif mode =="delete"
                    for id in ids
                        if haskey(griditems, id) && griditems[id].virtual_copy > 0
                            delete!(griditems, id)
                        end
                    end
                    @js_ w delete_images($ids)
                end
            catch e
                error(e, w)
            finally
                unlock(l)
                global griditems_last_changed = time()
            end
        elseif what == "export_odp"
            lock(l)
            filename_export = args[3]
            try
                export_odp(ids, dir_data, griditems, filename_export)
                @js_ w exported()
            catch e
                if (:msg in fieldnames(typeof(e)))  # this is often a file-busy error
                    msg = string(e.msg)
                    @js_ w show_error($msg)
                else
                    error(e, w)
                end
            finally
                unlock(l)
            end
        end
    end

    handle(w, "re_parse_images") do args
        parse_all = args[1]
        lock(l)
        try
            global cancel_sent = false  # user might send cancel during the next steps
            save_all(dir_data, griditems)
            griditems, griditems_new = parse_files(dir_data, only_new=!parse_all)
            bottomleft, topright = get_scan_range(griditems)
            if cancel_sent
                @js_ w console.log()
                global cancel_sent = false
            else
                # only send the images with status >=0 (deleted ones are not sent, but still saved)
                griditems_values = NaturalSort.sort!(collect(filter(im->im.status >= 0, collect(values(griditems)))), by=im -> (im.recorded, im.filename_original, im.virtual_copy))  # NaturalSort will sort number suffixes better
                if parse_all
                    json_compressed = transcode(GzipCompressor, JSON.json(griditems_values))
                    @js_ w load_images($json_compressed, $bottomleft, $topright, $parse_all, true)
                else
                    ids_after = String[]
                    griditems_sub = OrderedDict{String, SpmGridItem}()
                    prev_id = ""
                    global griditems_values_test = copy(griditems_values)
                    for im in griditems_values
                        if im.id in griditems_new
                            griditems_sub[im.id] = im
                            push!(ids_after, prev_id)
                        end
                        prev_id = im.id
                    end
                    @js_ w insert_images($griditems_sub, $ids_after)  # insert images after positions of ids
                end
            end
        catch e
            error(e, w)
        finally
            unlock(l)
            global griditems_last_changed = time()
        end
    end

    handle(w, "save_all") do args
        lock(l)
        if args[1] == true
            global exit_tycoon = true
        end
        force = args[2]
        saved = false
        try
            if dir_data != ""
                if force || (griditems_last_changed > griditems_last_saved - 180)
                    save_all(dir_data, griditems)
                    global griditems_last_saved = time()
                    saved = true
                end
            end
            @js_ w saved_all($saved)
        catch e
            error(e, w)
        finally
            unlock(l)
        end
    end

    handle(w, "exit") do args
        global exit_tycoon = true
    end

    return nothing
end


"""sets basic event handlers"""
function set_event_handlers_basic(w::Window)
    l = ReentrantLock()  # not sure if it is necessary to do it here, but it should be safer this way

    handle(w, "load_directory") do arg
        lock(l)
        try
            dir = abspath(arg)
            if !isdir(dir)
                msg = "Cannot open directory $dir"
                @js_ w page_start_load_error($msg)
            else
                load_directory(dir, w)
            end
        catch e
            error(e, w)
        finally
            unlock(l)
        end
    end

    handle(w, "cancel") do args
        global cancel_sent = true
    end

    handle(w, "debug") do args
        println("debug: " * string(args))
    end

    return nothing
end
