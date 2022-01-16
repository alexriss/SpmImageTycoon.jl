// called from julia

function load_page() {
    // loads the page contents
    const nodes = document.querySelectorAll('link[rel="import"]');  // blink.jl loads it into an html import
    const link = nodes[nodes.length - 1];
    document.body.innerHTML = link.import.querySelector('body').innerHTML;
    link.remove();  // remove this node, we wont need it anymore

    // set-up extra event handlers
    event_handlers();
}

function set_params(dir_res, auto_save_minutes, overview_max_images) {
    // set base directory for all relative paths (dir_res) and continuous auto-save
    const el = document.createElement('base');
    el.href = "file:///" + dir_res;
    document.getElementsByTagName('head')[0].appendChild(el);
    window.auto_save_minutes = auto_save_minutes;
    window.overview_max_images = overview_max_images;
}

function set_params_project(dir_data, dir_cache, dir_colorbars, filenames_colorbar) {
    //  sets the global variables needed for this current directory
    window.dir_data = dir_data;
    window.dir_cache = dir_cache;
    window.dir_colorbars = dir_colorbars;
    window.filenames_colorbar = filenames_colorbar;
}

function set_last_directories(dirs) {
    // sets last directories
    window.last_directories = dirs;
}

function show_start() {
    // shows start page
    toggle_start_project("start");
}

function load_images(gzip_json_images_parsed_arr, bottomleft, topright, delete_previous=false, open_job_close=false) {  // here we use the array "images_parsed_arr", because we have to preserve order (we use a json+gzip for faster communication)
    // load all images into the page
    let json_images_parsed_arr = require("zlib").gunzipSync(new Buffer.from(gzip_json_images_parsed_arr));
    let images_parsed_arr = JSON.parse(json_images_parsed_arr.toString("utf-8"));

    // delete previous images
    if (delete_previous) {
        // remove all nodes
        let els = document.getElementById('imagegrid').getElementsByClassName('item');
        while (els.length > 0) {
            els[0].remove();
        }

        els = document.getElementById('filter_overview').getElementsByClassName('filter_overview_item');
        while (els.length > 0) {
            els[0].remove();
        }

        // delete saved items
        window.items = {};
    }

    // make sure that the project page is visible
    if (delete_previous) {
        toggle_start_project("project");
    }

    // save scan ranges - we set them to a square
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

    // loads new images
    for (let i = 0, imax = images_parsed_arr.length; i < imax; i++) {
        window.items[images_parsed_arr[i].id] = images_parsed_arr[i];
        add_image(images_parsed_arr[i].id);
        images_parsed_arr[i].keywords.forEach((keyword) => {
            window.keywords_all.add(keyword);
        })
    }

    filter_items();
    document.getElementById('footer_num_images_total').innerText = images_parsed_arr.length;

    if (open_job_close) {
        open_jobs(-1);
    }
}

function update_images(gzip_json_images_parsed) {  // "images_parsed" is a dictionary here
    // updates images

    // let t1 = performance.now();
    // console.log("Update info get:" + (t1 - window.t0) + " ms.");

    let json_images_parsed = require("zlib").gunzipSync(new Buffer.from(gzip_json_images_parsed));
    let images_parsed = JSON.parse(json_images_parsed.toString("utf-8"));

    for (let key in images_parsed) {
        window.items[key] = images_parsed[key];
        update_image(key);
        images_parsed[key].keywords.forEach((keyword) => {
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

    filter_items(Object.keys(images_parsed));

    open_jobs(-1);
}

function insert_images(images_parsed, ids_after) {
    // inserts new images at specific positions (ids_after)

    let i = 0;
    for (let key in images_parsed) {
        window.items[key] = images_parsed[key];
        add_image(key, ids_after[i]);
        images_parsed[key].keywords.forEach((keyword) => {
            window.keywords_all.add(keyword);
        });
        i++;
    }

    filter_items(Object.keys(images_parsed));
    document.getElementById('footer_num_images_total').innerText = document.querySelectorAll('#imagegrid .item').length;

    open_jobs(-1);
}

function delete_images(ids) {
    // deletes images
    for (let i=0;i<ids.length;i++) {
        document.getElementById(ids[i]).remove();
        delete window.items[ids[i]];
    }

    // TODO: we could update the window.keywords - but for now we just leave it as is

    filter_items([]);  // no need to apply extra filtering now, so give empty array, so we will update the value in the filter sidebar
    document.getElementById('footer_num_images_total').innerText = document.querySelectorAll('#imagegrid .item').length;

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

    if (document.getElementById("sidebar_content").classList.contains("is-hidden")) {
        document.getElementById("sidebar_content_none").classList.add("is-hidden");
        document.getElementById("sidebar_content").classList.remove("is-hidden");
    }
    // let t1 = performance.now();
    // console.log("info unparse:" + (t1 - window.t0) + " ms.");

    const filename_original = window.items[id].filename_original
    document.getElementById("image_info_filename").innerText = filename_original.substring(0, window.items[id].filename_original.length - 4);
    document.getElementById("image_info_channel_name").innerText = window.items[id].channel_name;
    document.getElementById("image_info_background_correction").innerText = window.items[id].background_correction;
    if (window.items[id].type == "SpmGridSpectrum") {
        document.getElementById("image_info_scansize_or_xaxis").innerText = window.items[id].channel2_name;
        document.getElementById("image_info_angle_or_points").innerText = window.items[id].points + " pts";
        const num_channels = extra_info["Units"].split(", ").length - 1;  // we subtract one, becuase "Index" is not really a channel
        document.getElementById("image_info_colorscheme_or_channels").innerText =  num_channels + " chs";

        if (window.items[id].channel_range.length == 4) {  // first two are y-axis, second two are x-axis
            let xaxis_range_selected = [window.items[id].channel_range[2], window.items[id].channel_range[3]];
            if (window.items[id].channel_range_selected.length == 4) {  // first two are y-axis, second two are x-axis
                xaxis_range_selected[0] *= window.items[id].channel_range_selected[2];
                xaxis_range_selected[1] *= window.items[id].channel_range_selected[3];
            }
            const nnps = format_numbers_prefix(xaxis_range_selected, 1);
            document.getElementById("image_info_z_feedback_setpoint_or_xaxis_range").innerText = nnps[0].number_formatted +
                     " to " + nnps[1].number_formatted + " " + nnps[1].prefix + window.items[id].channel2_unit;
        } else {
            document.getElementById("image_info_z_feedback_setpoint_or_xaxis_range").innerText = "-" + window.items[id].channel2_unit;
        }

        if (window.items[id].channel_range_selected.length == 4) {
            // check deviation from (0,1) for xaxis
            const diff = Math.abs(window.items[id].channel_range_selected[2] - 0) + Math.abs(1 - window.items[id].channel_range_selected[3]);
            if (diff > 0.0005) {
                document.getElementById("image_info_xaxis_clamped").classList.remove("is-invisible");
            } else {
                document.getElementById("image_info_xaxis_clamped").classList.add("is-invisible");    
            }
        } else {
            document.getElementById("image_info_xaxis_clamped").classList.add("is-invisible");
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
            const diff = Math.abs(window.items[id].channel_range_selected[0] - 0) + Math.abs(1 - window.items[id].channel_range_selected[1]);
            if (diff > 0.0005) {
                document.getElementById("image_info_colorscheme_clamped").classList.remove("is-invisible");
            } else {
                document.getElementById("image_info_colorscheme_clamped").classList.add("is-invisible");    
            }
        } else {
            document.getElementById("image_info_colorscheme_clamped").classList.add("is-invisible");
        }

        if (window.items[id].z_feedback) {
            nnp = format_number_prefix(window.items[id].z_feedback_setpoint,1);
            document.getElementById("image_info_z_feedback_setpoint_or_xaxis_range").innerText = nnp.number_formatted +
            " " + nnp.prefix + window.items[id].z_feedback_setpoint_unit
        } else {
            nnp = format_number_prefix(window.items[id].z,3);  // we want high precision here
            document.getElementById("image_info_z_feedback_setpoint_or_xaxis_range").innerText = nnp.number_formatted +
            " " + nnp.prefix + "m";
        }

        // only used for spectra
        document.getElementById("image_info_xaxis_clamped").classList.add("is-invisible");
    }

    nnp = format_number_prefix(window.items[id].bias,1);
    document.getElementById("image_info_bias").innerText = nnp.number_formatted;
    document.getElementById("image_info_bias_unit_prefix").innerText = nnp.prefix;


    if (window.items[id].virtual_copy > 0) {
        document.getElementById("image_info_virtual_copy").classList.remove("is-hidden");
    } else {
        document.getElementById("image_info_virtual_copy").classList.add("is-hidden");
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

    if (window.datatable == null) {
        window.datatable = new simpleDatatables.DataTable("#image_info", {
            searchable: true,
            // fixedHeight: true,
            paging: false,
            scrollY: "calc(var(--vh, 1vh) * 100 - 15.6rem)",
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
    if (get_view() == "zoom" && window.zoom_last_selected == id) {
        if (window.histogram_object != null) {
            window.histogram_object.plot_histogram(width, counts);
        }
    }
    open_jobs(-1);
}

function show_line_profile(id, distances, values, start_point_value, end_point_value) {
    if (get_view() == "zoom" && window.zoom_last_selected == id) {
        if (window.line_profile_object != null) {
            window.window.line_profile_object.showLineValues(start_point_value, end_point_value);
            window.window.line_profile_object.plotLineProfile(distances, values);
        }
    }
    open_jobs(-1);
}

function saved_all() {
    // current state has been saved to disk
    open_jobs(-1);
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

function select_directory() {
    // select directory - open dialog
    if (get_view() != "start") {
        return;
    }
    const {remote} = require('electron');
    const dialog = remote.dialog;
    const win = remote.getCurrentWindow();
    let options = {
        title: "Load images from folder",
        properties: ['openDirectory'],
        multiSelections: false,
        defaultPath : window.dir_data,
        buttonLabel : "Open folder",
        // filters :[
        //  {name: 'Nanonis SPM images', extensions: ['sxm']},
        //  {name: 'All Files', extensions: ['*']}
        // ]
    }
    let directory = dialog.showOpenDialog(win, options);
    if (directory !== undefined) {
        if (Array.isArray(directory))
            load_directory(directory[0]);
        else {
            load_directory(directory[0]);
        }
    }
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

    let full_resolution = false;
    if (get_view() == "zoom") {
        full_resolution = true;
    }

    if (ids.length > 0) {
        Blink.msg("grid_item", ["next_" + what, ids, jump, full_resolution]);
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


function get_image_info(id="", histogram=false) {
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
            if (ids.length == 1) {
                id = ids[0];
            } else {
                id = window.image_info_id;
            }
        }
    }
    if (id != "") {
        window.image_info_id = id;
        if (histogram) {
            open_jobs(1);
        }
        Blink.msg("grid_item", ["get_info", [id], histogram]);
    }
}

function set_rating(rating, only_current=false) {
    // sets the rating for items.
    // if "only_current" is true, then only set the rating for the item displayed int he sidebar.
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
    let ids = get_active_element_ids(window.keywords_only_current);

    if (ids.length > 0) {
        Blink.msg("grid_item", ["set_keywords", ids, window.keywords_mode, window.keywords_input.value.map(a => a.value)]);
        open_jobs(1);  // julia will then set the radiobox
    }
}

function get_line_profile(id, start_point, end_point, width) {
    // request line profile for a certain image
    if (get_view() != "zoom" || id == "") {
        return;
    }
    Blink.msg("grid_item", ["get_line_profile", [id], [start_point.x, start_point.y], [end_point.x, end_point.y], width]);
    open_jobs(1);
}

function re_parse_images(all=false) {
    // delete all images from DOM and re-parses them
    if (get_view() == "grid" || all === false) {
        Blink.msg("re_parse_images", [all]);
        if (all) {
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

    console.log("Export to " + what);
    let ids = get_active_element_ids(only_current=false, all_visible_if_none_selected=true);

    if (ids.length > 0) {
        const {remote} = require('electron');
        const dialog = remote.dialog;
        const win = remote.getCurrentWindow();
        let options = {
            title: "Export as OpenDocument Presentation",
            defaultPath : window.dir_data,  // we could specify a filename here
            buttonLabel : "Export",
            filters :[
             {name: 'OpenDocument Presentations', extensions: ['odp']},
             {name: 'All Files', extensions: ['*']}
            ]
        }
        let filename = dialog.showSaveDialog(win, options)
        console.log(filename)

        if (filename !== undefined) {
            Blink.msg("grid_item", ["export_odp", ids, filename]);
            open_jobs(1);
            let plural_s = "";
            if (ids.length > 1) {
                plural_s = "s";
            }
            show_message("export " + ids.length + " file" + plural_s + " to presentation.")
        }
    }
}

function save_all(exit=false) {
    // saves the current state to disk
    if (get_view() != "start") {
        console.log("save all")
        Blink.msg("save_all", [exit]);
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

function load_directory(directory) {
    // loads directory
    console.log("load directory: " + directory);

    document.getElementById("page_start_open_directory").classList.add("is-hidden");
    document.getElementById("page_start_load_error").classList.add("is-hidden");
    document.getElementById("page_start_progress_bar").value = 0;
    document.getElementById("page_start_progress_num_files").innerText = "";
    document.getElementById("page_start_progress_directory").innerText = directory;
    document.getElementById("page_start_progress").classList.remove("is-hidden");
    
    Blink.msg("load_directory", directory);
}

