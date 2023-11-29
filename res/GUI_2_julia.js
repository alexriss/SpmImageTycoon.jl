// called from julia

function load_page(versions) {
    // loads the page contents
    const nodes = document.querySelectorAll('div.htmlimport');  // blink.jl loads it into an html import
    const last = nodes[nodes.length - 1];
    document.body.innerHTML = last.innerHTML;
    last.remove();  // remove this node, we wont need it anymore

    // set version numbers in about-modal
    window.versions = versions;
    document.getElementById("about_version_spmimagetycoon").innerText = versions["SpmImageTycoon"];
    document.getElementById("about_version_spmimages").innerText = versions["SpmImages"];
    document.getElementById("about_version_spmspectroscopy").innerText = versions["SpmSpectroscopy"];

    // shows/hides elements for pro mode
    tycoon_mode_setup();

    // setup menu
    setup_menu();

    // set-up extra event handlers
    event_handlers();

    // show info sidebar
    toggle_sidebar("info", true);
}

function set_params(dir_res, auto_save_minutes, overview_max_images, bg_corrections, directions_list, editing_entries, tycoon_mode) {
    // set base directory for all relative paths (dir_res) and continuous auto-save
    const el = document.createElement('base');
    el.href = "file:///" + dir_res;
    document.getElementsByTagName('head')[0].appendChild(el);
    window.auto_save_minutes = auto_save_minutes;
    window.overview_max_images = overview_max_images;
    window.background_corrections = bg_corrections;
    window.directions_list = directions_list;
    window.editing_entry_list = editing_entries;
    window.tycoon_mode = tycoon_mode;
}

function set_params_project(dir_data, dir_cache, dir_temp_cache, dir_colorbars, dir_edits, filenames_colorbar) {
    //  sets the global variables needed for this current directory
    window.dir_data = dir_data;
    window.dir_cache = dir_cache;
    window.dir_temp_cache = dir_temp_cache;
    window.dir_colorbars = dir_colorbars;
    window.dir_edits = dir_edits;
    window.filenames_colorbar = filenames_colorbar;

    setup_menu_project();
}

function set_last_directories(dirs) {
    // sets last directories
    window.last_directories = dirs;
}

function show_start() {
    // shows start page
    toggle_start_project("start");
}

function setup_filter_overview(bottomleft, topright, delete_previous=false) {
    // sets up limits for filter-overview

    if (delete_previous) {
        els = document.getElementById('filter_overview').getElementsByClassName('filter_overview_item');
        while (els.length > 0) {
            els[0].remove();
        }
    }

    // scan ranges - we set them to a square
    const w = topright[0]-bottomleft[0];
    const h = topright[1]-bottomleft[1];
    if (w > h) {
        bottomleft[1] = bottomleft[1] - (w-h) / 2;
        topright[1] = topright[1] + (w-h) / 2;
    } else if (h > w) {
        bottomleft[0] = bottomleft[0] - (h-w) / 2;
        topright[0] = topright[0] + (h-w) / 2;

    }
    window.bottomleft = bottomleft;
    window.topright = topright;
}

function load_images(gzip_json_griditems_arr, bottomleft, topright, delete_previous=false, open_job_close=false) {  // here we use the array "griditems_arr", because we have to preserve order (we use a json+gzip for faster communication)
    // load all images into the page
    let json_griditems_arr = require("zlib").gunzipSync(new Buffer.from(gzip_json_griditems_arr));
    let griditems_arr = JSON.parse(json_griditems_arr.toString("utf-8"));

    // delete previous images
    if (delete_previous) {
        // remove all nodes
        let els = document.getElementById('imagegrid').getElementsByClassName('item');
        while (els.length > 0) {
            els[0].remove();
        }

        // delete saved items
        window.items = {};
        window.keywords_all = new Set();
        
        // make sure that the project page is visible
        toggle_start_project("project");
    }

    setup_filter_overview(bottomleft, topright, delete_previous);

    // loads new images
    for (let i = 0, imax = griditems_arr.length; i < imax; i++) {
        window.items[griditems_arr[i].id] = griditems_arr[i];
        add_image(griditems_arr[i].id);
        griditems_arr[i].keywords.forEach((keyword) => {
            window.keywords_all.add(keyword);
        })
    }

    window.filter_items_object.filter_items([], -1, sort=true);
    document.getElementById('footer_num_images_total').innerText = griditems_arr.length;
    check_hover_enabled();

    if (open_job_close) {
        open_jobs(-1);
    }
}

function update_images(gzip_json_griditems, julia_queue_type="") {  // "griditems" is a dictionary here
    // updates images

    // let t1 = performance.now();
    // console.log("Update info get:" + (t1 - window.t0) + " ms.");

    let json_griditems = require("zlib").gunzipSync(new Buffer.from(gzip_json_griditems));
    let griditems = JSON.parse(json_griditems.toString("utf-8"));

    let ids = [];
    for (let key in griditems) {
        ids.push(key);
        window.items[key] = griditems[key];
        update_image(key);
        griditems[key].keywords.forEach((keyword) => {
            window.keywords_all.add(keyword);
        });
    }

    // t1 = performance.now();
    // console.log("Update info get1:" + (t1 - window.t0) + " ms.");

    // update image info
    if (get_view() != "zoom") {  // zoom view updates the image by itself
        image_info_quick();
        get_image_info();
    }

    // t1 = performance.now();
    // console.log("Update info get2:" + (t1 - window.t0) + " ms.");

    window.filter_items_object.filter_items(Object.keys(griditems), -1, sort=true);
    check_hover_enabled();

    open_jobs(-1, ids, julia_queue_type);
}

function insert_images(griditems, ids_after, bottomleft=[], topright=[]) {
    // inserts new images at specific positions (ids_after)

    if (bottomleft.length == 2 && topright.length == 2) {
        if (bottomleft[0] < window.bottomleft[0] || bottomleft[1] < window.bottomleft[1] || topright[0] > window.topright[0] || topright[1] > window.topright[1]) {
            setup_filter_overview(bottomleft, topright, delete_previous=true);
            for (const key of Object.keys(window.items)) {
                add_image_overview(key);
            }
        }
    }

    let i = 0;
    for (let key in griditems) {
        window.items[key] = griditems[key];
        add_image(key, ids_after[i]);
        griditems[key].keywords.forEach((keyword) => {
            window.keywords_all.add(keyword);
        });
        i++;
    }

    window.filter_items_object.filter_items(Object.keys(griditems), -1, sort=true);
    document.getElementById('footer_num_images_total').innerText = document.querySelectorAll('#imagegrid .item').length;
    check_hover_enabled();

    open_jobs(-1);
}

function delete_images(ids) {
    // deletes images
    for (let i=0;i<ids.length;i++) {
        document.getElementById(ids[i]).remove();
        delete window.items[ids[i]];

        let id_overview = "filter_overview_item_" + ids[i];
        document.getElementById(id_overview).remove();
    }

    // TODO: we could update the window.keywords - but for now we just leave it as is

    window.filter_items_object.filter_items([]);  // no need to apply extra filtering now, so give empty array, so we will update the value in the filter sidebar
    document.getElementById('footer_num_images_total').innerText = document.querySelectorAll('#imagegrid .item').length;
    check_hover_enabled();

    open_jobs(-1);
}

function re_parse_images_cancelled() {
    // just show a cancel message - nothing else to do
    show_message("reloading cancelled.")
    open_jobs(-1);
}

function show_info(id, gzip_info_json, extra_info={}) {
    /// shows header data for an image
    if (window.image_info_id != id) return;  // there was some other event already

    let info_json = require("zlib").gunzipSync(new Buffer.from(gzip_info_json));
    let nnp;

    if (document.getElementById("sidebar_info_content").classList.contains("is-invisible")) {
        document.getElementById("sidebar_info_content_none").classList.add("is-hidden");
        document.getElementById("sidebar_info_content").classList.remove("is-invisible");
    }
    // let t1 = performance.now();
    // console.log("info unparse:" + (t1 - window.t0) + " ms.");

    const filename_original = window.items[id].filename_original
    document.getElementById("image_info_filename").innerText = filename_original.substring(0, window.items[id].filename_original.length - 4);
    document.getElementById("image_info_channel_name").innerText = window.items[id].channel_name;
    document.getElementById("image_info_background_correction").innerText = window.items[id].background_correction;
    document.getElementById("image_info_edits").innerText = extra_info["active_edits_str"]
    
    if (window.items[id].type == "SpmGridSpectrum") {
        document.getElementById("image_info_scansize_or_xaxis").innerText = window.items[id].channel2_name;
        document.getElementById("image_info_angle_or_points").innerText = window.items[id].points + " pts";
        const num_channels = extra_info["Units"].split(", ").length - 1;  // we subtract one, because "Index" is not really a channel
        document.getElementById("image_info_colorscheme_or_channels").innerText =  num_channels + " chs";

        if (window.items[id].channel_range.length == 4) {  // first two are y-axis, second two are x-axis
            let xaxis_range_selected = [window.items[id].channel_range[2], window.items[id].channel_range[3]];
            if (window.items[id].channel_range_selected.length == 4) {  // first two are y-axis, second two are x-axis
                const scale_factor = (window.items[id].channel_range[3] - window.items[id].channel_range[2]);
                xaxis_range_selected[0] = window.items[id].channel_range[2] + window.items[id].channel_range_selected[2] * scale_factor;
                xaxis_range_selected[1] = window.items[id].channel_range[2] + window.items[id].channel_range_selected[3] * scale_factor;
            }
            const nnps = format_numbers_prefix(xaxis_range_selected, 1);
            document.getElementById("image_info_z_feedback_setpoint_or_xaxis_range").innerText = nnps[0].number_formatted +
                     " to " + nnps[1].number_formatted + " " + nnps[1].prefix + window.items[id].channel2_unit;
        } else {
            document.getElementById("image_info_z_feedback_setpoint_or_xaxis_range").innerText = "-" + window.items[id].channel2_unit;
        }

        if (window.items[id].channel_range_selected.length == 4) {
            // check deviation from (0,1) for xaxis
            const diff = 2 - Math.abs(window.items[id].channel_range_selected[3] - window.items[id].channel_range_selected[2]) -
                Math.abs(window.items[id].channel_range_selected[1] - window.items[id].channel_range_selected[0]);
            if (diff > 0.0005) {
                document.getElementById("image_info_xaxis_clamped").classList.remove("is-invisible");
            } else {
                document.getElementById("image_info_xaxis_clamped").classList.add("is-invisible");    
            }
            if (window.items[id].channel_range_selected[1] - window.items[id].channel_range_selected[0] < 0) {
                document.getElementById("image_info_channel_inverted").classList.remove("is-hidden");
            } else {
                document.getElementById("image_info_channel_inverted").classList.add("is-hidden");
            }
            if (window.items[id].channel_range_selected[3] - window.items[id].channel_range_selected[2] < 0) {
                document.getElementById("image_info_xaxis_inverted").classList.remove("is-hidden");
            } else {
                document.getElementById("image_info_xaxis_inverted").classList.add("is-hidden");
            }
        } else {
            document.getElementById("image_info_xaxis_clamped").classList.add("is-invisible");
            document.getElementById("image_info_channel_inverted").classList.add("is-hidden");
            document.getElementById("image_info_xaxis_inverted").classList.add("is-hidden");
        }

        // only needed for images
        document.getElementById("image_info_colorscheme_clamped").classList.add("is-invisible");
        document.getElementById("image_info_scan_direction_up").classList.add("is-hidden");
        document.getElementById("image_info_scan_direction_down").classList.add("is-hidden");
    } else { // images
        document.getElementById("image_info_scansize_or_xaxis").innerText =
            number_max_decimals(window.items[id].scansize[0], 3) + " x " + number_max_decimals(window.items[id].scansize[1], 3)
            + " " + window.items[id].scansize_unit;
        document.getElementById("image_info_colorscheme_or_channels").innerText = window.items[id].colorscheme;
        document.getElementById("image_info_angle_or_points").innerHTML = window.items[id].angle.toFixed(0) + "&deg;";

        if (window.items[id].scan_direction) {
            document.getElementById("image_info_scan_direction_up").classList.remove("is-hidden");
            document.getElementById("image_info_scan_direction_down").classList.add("is-hidden");
        } else {
            document.getElementById("image_info_scan_direction_up").classList.add("is-hidden");
            document.getElementById("image_info_scan_direction_down").classList.remove("is-hidden");
        }
        
        if (window.items[id].channel_range_selected.length == 2) {
            const diff = 1 - Math.abs(window.items[id].channel_range_selected[1] - window.items[id].channel_range_selected[0]);
            if (diff > 0.0005) {
                document.getElementById("image_info_colorscheme_clamped").classList.remove("is-invisible");
            } else {
                document.getElementById("image_info_colorscheme_clamped").classList.add("is-invisible");    
            }
        } else {
            document.getElementById("image_info_colorscheme_clamped").classList.add("is-invisible");
        }

        if (window.items[id].z_feedback) {
            if (window.items[id].z_feedback_setpoint_unit == "") {
                document.getElementById("image_info_z_feedback_setpoint_or_xaxis_range").innerText = "";
            } else {
                nnp = format_number_prefix(window.items[id].z_feedback_setpoint,1);
                document.getElementById("image_info_z_feedback_setpoint_or_xaxis_range").innerText = nnp.number_formatted +
                " " + nnp.prefix + window.items[id].z_feedback_setpoint_unit
            }
        } else {
            nnp = format_number_prefix(window.items[id].z,3);  // we want high precision here
            document.getElementById("image_info_z_feedback_setpoint_or_xaxis_range").innerText = nnp.number_formatted +
            " " + nnp.prefix + "m";
        }

        // only used for spectra
        document.getElementById("image_info_xaxis_clamped").classList.add("is-invisible");
        document.getElementById("image_info_channel_inverted").classList.add("is-hidden");
        document.getElementById("image_info_xaxis_inverted").classList.add("is-hidden");
    }

    nnp = format_number_prefix(window.items[id].bias,1);
    document.getElementById("image_info_bias").innerText = nnp.number_formatted;
    document.getElementById("image_info_bias_unit_prefix").innerText = nnp.prefix;


    if (window.items[id].virtual_copy > 0) {
        document.getElementById("image_info_virtual_copy").classList.remove("is-hidden");
    } else {
        document.getElementById("image_info_virtual_copy").classList.add("is-hidden");
    }

    if (window.items[id].status == 10) {
        document.getElementById("editing_entry_main_filename_temp_cache").classList.remove("is-hidden");
    } else {
        document.getElementById("editing_entry_main_filename_temp_cache").classList.add("is-hidden");
    }

    const rating = window.items[id].rating;
    document.getElementsByName("image_info_rating")[rating].checked = true;

    // remove old keywords
    let els = document.getElementById('sidebar_keywords_container').getElementsByClassName('tag');
    while (els.length > 0) {
        els[0].remove();
    }
    const template_keyword = document.getElementById('sidebar_keywords');
    window.items[id].keywords.forEach(keyword => {
        let el_keyword = template_keyword.content.firstElementChild.cloneNode(true);
        el_keyword.innerText = keyword;
        document.getElementById("sidebar_keywords_container").appendChild(el_keyword);
    });

    if (!document.getElementById("sidebar_imagezoomtools").classList.contains("is-hidden")) {
        window.editing_object.setup_form(id, extra_info);
    }  

    if (window.datatable == null) {
        window.datatable = new simpleDatatables.DataTable("#image_info", {
            searchable: true,
            // fixedHeight: true,
            paging: false,
            scrollY: "calc(var(--vh, 1vh) * 100 - 15.6rem - 1rem)",
            // fixedColumns: true,
            // columns: { select: [2], sortable: false },
        })
        document.getElementById("table-container").style.display = "block";
    } else {
        window.datatable.rows().remove("all");
    }
    window.datatable.import({
        type: "json",
        data: info_json,
    });
    // t1 = performance.now();
    // console.log("info unparse (create table):" + (t1 - window.t0) + " ms.");
}

function show_histogram(id, width, counts) {
    // histogram in zoom view
    if (get_view() == "zoom" && window.zoom_last_selected == id) {
        if (window.histogram_object != null) {
            window.histogram_object.plot_histogram(width, counts);
        }
    }
}

function show_line_profile(id, distances, values, start_point_value, end_point_value) {
    if (get_view() == "zoom" && window.zoom_last_selected == id) {
        if (window.line_profile_object != null) {
            window.line_profile_object.showLineValues(start_point_value, end_point_value);
            window.line_profile_object.plotLineProfile(distances, values);
        }
    }
    open_jobs(-1);
}

function set_channels_menu(channels, channels2) {
    // we dont check whether the ids match, to save time
    setup_menu_selection_callback(channels, channels2);
    open_jobs(-1);
}

function show_spectrum(id, gzip_json_spectrum_data) {
    if (get_view() == "zoom" && window.zoom_last_selected == id) {
        let json_spectrum_data = require("zlib").gunzipSync(new Buffer.from(gzip_json_spectrum_data));
        let spectrum_data = JSON.parse(json_spectrum_data.toString("utf-8"));

        if (window.spectrum_plot_object != null) {
            window.spectrum_plot_object.plotSpectrum(spectrum_data);
        }
    }
}

function show_info_done() {
    open_jobs(-1);
}

function saved_all(saved) {
    // current state has been saved to disk
    if (saved) {
        console.log("changes saved.")
    } else {
        console.log("no db changes.")
    }
    open_jobs(-1);
}

function export_start(ids, fname) {
    // julia starts exporting a presentation
    open_jobs(1);
    let plural_s = "";
    if (ids.length > 1) {
        plural_s = "s";
    }
    const str_num_files = "" + ids.length + " file" + plural_s;
    console.log("Export " + str_num_files + " to " + fname);
    show_message("export " + str_num_files + " to presentation.")
}

function exported() {
    // exported presentation
    open_jobs(-1);
}

function show_error(message) {
    // shows an error message
    console.log("error: " + message);
    let el = document.querySelector('#modal_error .message');
    if (get_view() == "error") {
        el.innerHTML = el.innerHTML + "<br /><br />" + message;
    } else {
        el.innerHTML = message;
        toggle_error();
    }
    open_jobs(-1);
}

function page_start_load_params(num_files) {
    // sets the parameters for the current directory
    document.getElementById("page_start_progress_num_files").innerText = num_files;
}

function page_start_load_progress(value) {
    // updates the progress bar
    document.getElementById("page_start_progress_bar").value = value;
}

function page_start_load_error(message) {
    // displays an error that occured during load
    document.getElementById("page_start_open_directory").classList.remove("is-hidden");
    document.getElementById("page_start_progress").classList.add("is-hidden");

    const el_error = document.getElementById("page_start_load_error");
    const el_error_message = document.getElementById("page_start_load_error_message")
    el_error.classList.remove("bounce");
    el_error_message.innerText = message;
    el_error.classList.remove("is-hidden");
    el_error.classList.add("bounce");
}

function load_notification_temp_cache(fnames) {
    // displays a notification if the temp cache was used for some items
    console.log("temp cache used for " + fnames);
    document.getElementById("notification_temp_cache_items").innerHTML = fnames.join("<br />");

    const el = document.getElementById("notification_temp_cache");
    el.classList.remove("is-hidden");

    window.timeout_notification["temp_cache"] = window.setTimeout(function() {
        el.classList.add("is-hidden");
    }, 5000);
}

function header_data(json) {
    // just for testing
    let t0 = performance.now();
    d = JSON.parse(json);
    let t1 = performance.now();
    console.log("JSON unparse:" + (t1 - t0) + " ms.");
}


// calling julia

function change_item(what, message, jump=1) {
    console.log("change: " + what);
    let ids = get_active_element_ids();

    const full_resolution = (get_view() == "zoom") ? true : false;

    if (ids.length > 0) {
        Blink.msg("grid_item", ["next_" + what, ids, jump, full_resolution]);
        open_jobs(1);
        show_message(message);
    }
}

function recalculate_items(ids, state, queue_type="", message="") {
    console.log("recalculate");
    
    if (ids == null) {
        ids = get_active_element_ids();
    }

    const full_resolution = (get_view() == "zoom") ? true : false;

    if (ids.length > 0) {
        Blink.msg("grid_item", ["set_multiple", ids, state, queue_type, full_resolution]);
        open_jobs(1);
        if (message !== "") {
            show_message(message);
        }
    }
}

function reset_item(what, message) {
    console.log(what);
    let ids = get_active_element_ids();

    const full_resolution = (get_view() == "zoom") ? true : false;

    if (ids.length > 0) {
        Blink.msg("grid_item", [what, ids, full_resolution]);
        open_jobs(1);
        show_message(message)
    }
}

function paste_parameters(message) {
    // paste parameters from one item to other items
    const v = get_view();
    if (v != "zoom" && v != "grid") {  // we use copy&paste also for keywords
        return;
    }
    console.log("paste parameters");
    let ids = get_active_element_ids();

    let full_resolution = false;
    if (v == "zoom") {
        full_resolution = true;
    }

    if (ids.length > 0 && window.last_copy_from != "") {
        Blink.msg("grid_item", ["paste_params", ids, window.last_copy_from, full_resolution]);
        open_jobs(1);
        show_message(message)
    }
}

function virtual_copy(mode) {
    // creates or deletes virtual images
    console.log("virtual item: " + mode);

    let ids = get_active_element_ids();
    if (ids.length > 0) {
        if (mode == "create") {
            Blink.msg("grid_item", ["virtual_copy", ids, mode]);
            open_jobs(1);
            if (ids.length == 1) {
                show_message("create virtual copy.");
            } else {
                show_message("create virtual copies.");
            }
        } else if (mode == "delete") {
            let ids_virtual = [];
            for (let i=0; i<ids.length; i++) {
                if (window.items[ids[i]].virtual_copy > 0) {
                    ids_virtual.push(ids[i]);
                }
            }
            if (ids_virtual.length > 0) {
                Blink.msg("grid_item", ["virtual_copy", ids_virtual, mode]);
                open_jobs(1);
                if (ids_virtual.length == 1) {
                    show_message("delete virtual copy.");
                    if (get_view() == "zoom") {  // we deleted the one that was shown
                        toggle_imagezoom("grid");
                    }
                } else {
                    show_message("delete virtual copies.");
                }    
            } else {
                show_message("No virtual copies within selection.");
            }
        }
    }
}

function change_item_range(id, range_selected) {
    // changes the displayed range for the image
    const full_resolution = true;
    window.t0 = performance.now();
    Blink.msg("grid_item", ["set_range_selected", [id], range_selected, full_resolution])
    open_jobs(1);
}

function change_spectrum_range(id, range_selected) {
    // sets channel_range_selected for respective spectrum
    if (get_view() != "zoom" || id == "" || window.items[id].type != "SpmGridSpectrum") {
        return;
    }
    console.log("set range_selected for spectrum.")
    Blink.msg("grid_item", ["set_range_selected_spectrum", [id], range_selected]);
    open_jobs(1);
}

function get_image_info(id="", zoomview=false) {
    // gets info (header data) for the current image

    // console.log("get info");
    // window.t0 = performance.now();
    if (id == "") {
        const el = document.getElementById('imagegrid').querySelector('div.item:hover');
        if (el != null) {
            id = el.id;
        }
        else {
            ids = get_active_element_ids();
            if (ids.length >= 1) {
                if (ids.includes(window.last_selected)) {
                    id = window.last_selected;
                } else {
                    id = ids[0];
                }
            } else {
                id = window.image_info_id;
            }
        }
    }
    if (id != "") {
        window.image_info_id = id;
        if (zoomview) {
            open_jobs(1);
        }
        Blink.msg("grid_item", ["get_info", [id], zoomview]);
    }
}

function set_rating(rating, only_current=false) {
    // sets the rating for items.
    // if "only_current" is true, then only set the rating for the item displayed in the sidebar.
    console.log("set rating to: " + rating);

    let ids = get_active_element_ids(only_current);

    if (ids.length > 0) {
        Blink.msg("grid_item", ["set_rating", ids, rating]);
        open_jobs(1);  // julia will then set the radiobox
    }
}

function set_keywords() {
    // sets keywords for items
    console.log("set keywords.")

    window.keywords_input.DOM.input.blur();  // so that the last typed keyword is transformed into a keyword, too
    const ids = get_active_element_ids(window.keywords_only_current, false, any_view=true);  // current view is "keywords", so we have to add the any_view parameter to get ids

    const keywords_mode = (ids.length == 1) ? "set" : window.keywords_mode;  // if only one is select_directory, mode is always "set"
    if (ids.length > 0) {
        Blink.msg("grid_item", ["set_keywords", ids, keywords_mode, window.keywords_input.value.map(a => a.value)]);
        open_jobs(1);  // julia will then set the radiobox
    }
}

function get_channels() {
    // gets the channels and channels2 for the current selection
    let ids = get_active_element_ids();

    if (ids.length > 0) {
        Blink.msg("grid_item", ["get_channels", ids]);
        open_jobs(1);
    }
}

function get_line_profile(id, start_point, end_point, width) {
    console.log(start_point, end_point, width);
    // request line profile for a certain image
    if (get_view() != "zoom" || id == "") {
        return;
    }

    // sometimes there seems to be a race condition where this function is called from a spectrum
    if (window.items[id].type != "SpmGridImage") {
        return;
    }
    Blink.msg("grid_item", ["get_line_profile", [id], [start_point.x, start_point.y], [end_point.x, end_point.y], width]);
    open_jobs(1);
}

function re_parse_images(all=false, force_selected=false) {
    // look for new images. if all==true, then delete all images from DOM and re-parses them
    // if force_selected==true, then force re-parse the selected images
    if (get_view() == "grid" || !all) {
        let ids = [];
        if (all && force_selected) {
            ids = get_active_element_ids();
        }
        Blink.msg("re_parse_images", [all, ids]);

        if (all && ids.length > 0) {
            show_message("clearing cache and reloading all images.")
        } else if (all) {
            show_message("reloading all images.")
        } else {
            show_message("looking for new images.")
        }
        open_jobs(1);
    }
}

function export_to(what) {
    // export as a presentation; opens dialog to choose filename
    if (get_view() != "grid") {
        return;
    }
    let ids = get_active_element_ids(only_current=false, all_visible_if_none_selected=true);
    if (ids.length > 0) {
        Blink.msg("grid_item", ["export_odp", ids]);
    }
}

function save_all(exit=false, force=false) {
    // saves the current state to disk
    if (get_view() != "start") {
        console.log("save all");
        Blink.msg("save_all", [exit, force]);
        show_message("saving.")
        open_jobs(1);
    } else if (exit == true) {
        Blink.msg("exit", []);
    }
}

function send_cancel() {
    // sends cancel signal (which will be listened to during parsing and reparsing of images)
    console.log("cancel");
    Blink.msg("cancel", []);
}

function select_directory() {
    // select directory - open dialog
    if (get_view() != "start") {
        return;
    }
    Blink.msg("select_directory", [window.dir_data]);
}

function load_directory(directory) {
    // loads directory
    console.log("load directory: " + directory);

    document.getElementById("page_start_open_directory").classList.add("is-hidden");
    document.getElementById("page_start_load_error").classList.add("is-hidden");
    document.getElementById("page_start_progress_bar").value = 0;
    document.getElementById("page_start_progress_num_files").innerText = "";
    document.getElementById("page_start_progress_directory").innerText = directory;  // "/home/riss/awesome projects/2022/project 51/";
    document.getElementById("page_start_progress").classList.remove("is-hidden");
    
    Blink.msg("load_directory", [directory]);
}

function toggle_dev_tools() {
    // toggles dev tools
    Blink.msg("devtools", []);
}


