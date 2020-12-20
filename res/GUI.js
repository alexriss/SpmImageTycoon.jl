window.dir_res = "";  // resources directory
window.dir_cache = "";  // will be set by julia
window.dir_colorbars = "";  // colorbars are saved here, ste by julia
window.filenames_colorbar = {};  // dictionary specifying the filenames for the colorbars, set by julia
window.items = {};  // dictionary with ids as keys and a dictionary of filenames as values

window.auto_save_minutes = 0  // auto-save every n minutes (will be set by julia)

window.last_selected = "";  // last selected item
window.zoom_control_setup = false;  // whether drag/zoom for zoomview is setup
window.zoom_last_selected = "";  // last selected image for zoom

window.histogram_object = null;  // holds the histogram object

window.num_open_jobs = 0;  // how many julia jobs are open
window.timeout = null;  // timeout reference
window.timeout_image_info = null;  //timeout refrence for get_image_info function
window.timeout_image_info_quick = null;  //timeout refrence for get_image_info_quick function
window.image_info_id = "";  // current image, for which data is displayed
window.datatable = null;  // holds the datatable

window.keywords_input = null;  // holds the keywords object
window.keywords_all = new Set();  // set of all possible keywords (for suggestions)

window.keywords_input_initial_value = "";  // balue that is set when opening the dialog (we want to know if the user changed it)

window.keywords_mode = "set";  // current mode for editing keywords
window.keywords_modes = ["set", "add", "remove"];   // different modes for editing keywords - warning: any change needs to be also done in the js code below and in Julia
window.keywords_modes_display = ["set", "add", "remove"];  // these descriptions are shown to the user

window.timeout_filter = null;  //timeout refrence for filter function
window.queue_filter_items = [];  // queue for filter_items functions - only one instance should run at a time

window.t0 = 0;   // for performance measurements

// helper functions

function number_max_decimals(num, max_decimals) {
    // returns a numbers with a maxmimum precision of max_decimals
    return Math.round((num) * 10**max_decimals) / 10**max_decimals
}

function create_regexp(inputstring) {
    // creates regexp form user input
    let flags = inputstring.replace(/.*\/([gimy]*)$/, '$1');
    if (flags == inputstring) {
        flags = ""
    }
    let pattern = inputstring.replace(new RegExp('^(.*?)/'+flags+'$'), '$1');
    return new RegExp(pattern, flags); 
}

function file_url(id) {
    // returns the display filename url
    const item = window.items[id];
    return 'file:///' + window.dir_cache + item.filename_display +
         "?" + item.channel_name + "_" + item.background_correction + "_" + item.colorscheme +
         "_range" + item.channel_range_selected[0] + "_" + item.channel_range_selected[1];  // to prevent caching and force reload
}

function file_url_colorbar(id) {
    // returns the colorbar url
    const item = window.items[id];
    return 'file:///' + window.dir_colorbars + window.filenames_colorbar[item.colorscheme];
}



// GUI functions

function open_jobs(diff) {
    // tracks the number of open julia jobs and displays spinner as long as there are some
    window.num_open_jobs += diff;
    if (window.num_open_jobs > 0) {
        document.getElementById("spinner_title").classList.remove("is-invisible");
    } else {
        document.getElementById("spinner_title").classList.add("is-invisible");
    }
}

function toggle_help() {
    // toggle  help modal
    if (document.getElementById("modal_help").classList.contains("is-active")) {
        document.getElementById("modal_help").classList.remove("is-active");
    } else {
        document.getElementById("modal_help").classList.add("is-active");
    }
}

function toggle_dev_tools() {
    // toggles dev tools
    require('electron').remote.getCurrentWindow().toggleDevTools();
}

function toggle_keywords_dialog(only_current=false) {
    // toggle keywords dialog
    if (document.getElementById("modal_keywords").classList.contains("is-active")) {
        document.getElementById("modal_keywords").classList.remove("is-active");
    } else {
        window.keywords_only_current = only_current;
        let ids = get_active_element_ids(only_current);

        if (ids.length > 0) {
            if (window.keywords_input === null) {
                window.keywords_input = new Tagify(document.getElementById("modal_keywords_input"), {
                    whitelist: [],
                    placeholder: "Add keywords",
                    dropdown: {
                        maxItems: 16,                 // maximum number of suggestions
                        classname: "tags-look",       // custom classname for dropdown
                        enabled: 1,                   // show suggestions after 1 character
                        // enabled: 0,                // show suggestions on focus
                        closeOnSelect: false          // do not hide suggestion dropdown after an item has been selected
                    }
                });
            }

            if (ids.length > 1) {  // show different modes
                document.getElementById("modal_keywords_mode_container").classList.remove("is-hidden");
            } else {
                document.getElementById("modal_keywords_mode_container").classList.add("is-hidden");
            }
            toggle_keywords_mode(jump=0, initial=true);  // also sets the inital keywords

            let whitelist =  Array.from(window.keywords_all).sort();
            window.keywords_input.settings.whitelist.splice(0, whitelist.length, ...whitelist);

            if (ids.length == 1) {
                filename_original = window.items[ids[0]].filename_original;
                document.getElementById("modal_keywords_files").innerText = filename_original.substring(0, filename_original.length - 4);
            } else {
                document.getElementById("modal_keywords_files").innerText = ids.length.toString() + ' files';
            }
            document.getElementById("modal_keywords").classList.add("is-active");
            window.keywords_input.DOM.input.focus();
        }
    }
}

function toggle_keywords_mode(jump=1, initial=false) {
    // toggles the keywords mode (and sets the keywords if initial=true or the user hasn't changed anything)
    const el = document.getElementById("modal_keywords_mode");
    let index = window.keywords_modes.indexOf(window.keywords_mode) + jump;
    index = index % window.keywords_modes.length;
    if (index < 0) {
        index = 0;
    }

    window.keywords_mode = window.keywords_modes[index];
    el.innerText = window.keywords_modes_display[index];

    if (initial || window.keywords_input_initial_value == JSON.stringify(window.keywords_input.value)) {  // user has not changed anything
        window.keywords_input.removeAllTags();
        window.keywords_input.addTags(keywords_initial_value());
        window.keywords_input_initial_value = JSON.stringify(window.keywords_input.value);  // need to copy
    }

    if (el.innerText == "remove") {
        document.getElementById("modal_keywords_mode").classList.add("is-danger");
    } else {
        document.getElementById("modal_keywords_mode").classList.remove("is-danger");
    }
}

function keywords_initial_value() {
    // depending on the mode, we will put a different set of keywords into the text-input
    let ids = get_active_element_ids(window.keywords_only_current);
    let keywords_result = [];
    let mode = window.keywords_mode;
    if (ids.length <= 1) {
        mode = "set";
    }
    if (mode == "add") {
        keywords_result = [];
        // // put the intersection of all keywords
        // keywords_result = window.items[ids[0]].keywords;
        // ids.forEach(id => {
        //     keywords_result = keywords_result.filter(k => window.items[id].keywords.includes(k));
        // });
    } else if (mode == "remove") {  // put empty list
        keywords_result = [];
    } else {  // "set", put the union of all keywords
        let keywords_with_duplicates = [];
        ids.forEach(id => {
            keywords_with_duplicates = keywords_with_duplicates.concat(window.items[id].keywords);
        });
        keywords_result = Array.from(new Set(keywords_with_duplicates));
    }
    keywords_result.sort();
    return keywords_result;
}

function keywords_copy_to_clipboard(event) {
    // copies all keywords to the clipboard
    const {clipboard} = require('electron');
    let text = window.keywords_input.value.map(a => a.value).join(",");
    clipboard.writeText(text);
}

function toggle_sidebar(what="info", show_sidebar=false, hide_others=false) {
    // toggles sidebar
    let sidebars = document.getElementsByClassName("sidebar");
    let sidebar = document.getElementById('sidebar_' + what);

    // hide all other sidebars
    if (hide_others) {
        for (let i=0; i<sidebars.length; i++) {
            if (sidebars[i] != sidebar) {
                sidebars[i].classList.add("is-hidden");
            }
        }
    }
    
    // toggle the selected sidebar
    if (sidebar.classList.contains("is-hidden") || show_sidebar) {
        sidebar.classList.remove("is-hidden");
        if (what == "info") {
            get_image_info();  // update info of current or last image
        }
    } else {
        sidebar.classList.add("is-hidden");
    }
}

function get_view() {
    if (document.getElementById("modal_help").classList.contains("is-active")) {
        return "help";
    } else if (document.getElementById("modal_keywords").classList.contains("is-active")) {
        return "keywords";
    } else if (document.getElementById('imagegrid_container').classList.contains("is-hidden")) {
        return "zoom";
    } else {
        return "grid";
    }
}

function toggle_imagezoom_mouse(event) {
    // switches to imagezoom mode via a mouse event (only if no modifier is pressed)
    if (!event.ctrlKey && !event.shiftKey) {
        toggle_imagezoom("zoom");
    }
}

function toggle_imagezoom(target_view = "") {
    // toggles between grid and imagezoom views

    const grid = document.getElementById('imagegrid_container');
    const zoom = document.getElementById('imagezoom_container');
    const footer_num_images_container = document.getElementById('footer_num_images_container');

    if (get_view() == "help") {
        toggle_help();
    } else if (get_view() == "keywords") {
        toggle_keywords_dialog();
    } else if (get_view() == "zoom" || target_view == "grid") {
        zoom.classList.add("is-hidden");
        grid.classList.remove("is-hidden");
        footer_num_images_container.classList.remove("is-invisible");
        image_info_quick_timeout_clear();  // if we leave zoom-mode, we imght need to get rid of the quick image info (if mouse is not hovering anything)
    } else {
        let el = grid.querySelector('div.item:hover');
        if (el != null) {
            grid.classList.add("is-hidden");
            zoom.classList.remove("is-hidden");
            footer_num_images_container.classList.add("is-invisible")

            window.image_info_id = el.id;  // should be set already, but just to make sure
            // get_image_info(el.id);  // should also not be necessary

            const zoom_content = document.getElementById('imagezoom_content');
            if (!window.zoom_control_setup) {
                zoom_drag_setup(zoom_content);
                window.zoom_control_setup = true;
            }
            if (window.zoom_last_selected != el.id) {
                // document.getElementById('imagezoom_image').src = file_url(el.id);
                zoom_drag_reset(zoom_content);
            }
            window.zoom_last_selected = el.id;
            next_item(0); // sets the img src and displays colorbar etc
        }
    }
}

function show_message(msg = "") {
    // shows message in the footer
    if (window.timeout != null) {
        clearTimeout(window.timeout);
    }
    let el = document.getElementById('footer_message');
    el.innerText = msg;
    window.timeout = setTimeout(show_message, 2500);
}

function clear_all_active_mouse(event) {
    // clears all active items upon mouse double-click (only when modifier key is pressed)
    if (!event.ctrlKey && !event.shiftKey) {
        return;
    }
    clear_all_active();
}

function clear_all_active() {
    // clears all active items
    if (get_view() != "grid") {
        return;
    }
    const grid = document.getElementById('imagegrid');
    const els = grid.getElementsByClassName('active');
    for (let i = els.length - 1; i >= 0; i--) {
        els[i].classList.remove('active');
    }
    check_hover_enabled();
}

function toggle_all_active(ignored_filtered=false) {
    // toggles between select-all and select-none
    if (get_view() != "grid") {
        return;
    }

    if (ignored_filtered) {
        const els = document.querySelectorAll('#imagegrid .item:not(.active)');
        if (els.length == 0) {
            clear_all_active();
        } else {
            for (let i = 0; i < els.length; i++) {
                els[i].classList.add('active');
            }
        }
    } else {
        const els = document.querySelectorAll('#imagegrid .item:not(.is-hidden):not(.active)');
        if (els.length == 0) {
            clear_all_active();
        } else {
            for (let i = 0; i < els.length; i++) {
                els[i].classList.add('active');
            }
        }
    }
    check_hover_enabled();
}

function get_active_element_ids(only_current=false) {
    // returns all active element ids
    // for zoom view, an array with this one element is returned
    // for grid view, if any are selected (i.e active), then these are returned
    //    .. unless only_current is true, then only this is returned
    // otherwise if one is hovered, then this is returned
    // otherwise an empty array is returned

    // help view
    if (get_view() == "help") {
        return [];
    }
    // zoom view
    if (get_view() == "zoom") {
        return [window.image_info_id];
    }

    // grid view
    const grid = document.getElementById('imagegrid');
    let els = grid.getElementsByClassName('active');

    if (only_current) {
        if (window.image_info_id == "") {
            return [];
        } else {
            return [window.image_info_id];
        }
    }

    if (els.length == 0) {
        els = grid.querySelectorAll('div.item:not(.active):hover')
    }

    if (els.length == 0) {
        if (window.image_info_id == "") {
            return [];
        } else {
            return [window.image_info_id];
        }
    }

    els_id = new Array(els.length)
    for (let i = 0; i < els.length; i++) {
        els_id[i] = els[i].id;
    }
    return els_id;
}

function check_hover_enabled() {
    // checks whether the magedrid should get the class hover_enabled
    // this is the case only if no active div.item elements are found
    // also writes the number of selected images into the footer.
    const grid = document.getElementById('imagegrid');
    const els = grid.getElementsByClassName('item active');
    if (els.length == 0) {
        grid.classList.add('hover_enabled');
    } else {
        grid.classList.remove('hover_enabled');
    }

    document.getElementById('footer_num_images').innerText = els.length;

    if (els.length > 1) {
        document.getElementById('footer_num_images_container').classList.add("has-text-weight-bold");
    } else {
        document.getElementById('footer_num_images_container').classList.remove("has-text-weight-bold");
    }
}

function next_item(jump) {
    // jumps a number of items forward or backward (only in zoom mode currently)
    if (get_view() != "zoom") {
        return;
    }

    let el = document.getElementById(window.zoom_last_selected);
    let elnext = el;
    let out_of_range = false;
    i = 0;
    while (i != jump) {
        if (jump > 0) {
            elnext = el.nextSibling;
            i++;
        } else {
            elnext = el.previousSibling;
            i--;
        }

        if (elnext === null || elnext.classList === undefined) {
            out_of_range = true;  // we do not need to update anything, because we stay at the current element
            break;
        } else if (elnext.classList.contains("is-hidden") || !elnext.classList.contains("item")) {    // do not count hidden items
            i = i - Math.sign(jump);  // revert - hidden elementsa do not count
        }

        el = elnext;
    }
    if (el.id in window.items && !out_of_range) {
        document.getElementById('imagezoom_image').src = file_url(el.id)
        document.getElementById('imagezoom_colorbar').src = file_url_colorbar(el.id);
        if (window.histogram_object === null) {
            window.histogram_object = new Histogram();
        }
        window.histogram_object.set_range_initial(window.items[el.id].channel_range, window.items[el.id].channel_range_selected, window.items[el.id].channel_unit);

        window.image_info_id = el.id;
        window.zoom_last_selected = el.id;
        image_info_timeout(null, el.id, histogram=true, timeout_ms=30);
    }
}

function select_item(event) {
    // selects one item or a bunch of items (if shift or ctrl is pressed)

    if (get_view() != "grid") {
        return;
    }

    const modifier = (event.ctrlKey || event.shiftKey);
    const items = Array.from(document.querySelectorAll('#imagegrid .item:not(.is-hidden)'));
    let end = items.indexOf(this);
    let start = items.indexOf(document.getElementById(window.last_selected));
    if (modifier && window.last_selected != "" && start != end) {
        if (start > end) {
            [start, end] = [end, start];
        }

        els = items.slice(start, end + 1);
        let all_active = true;
        for (let i = 0; i < els.length; i++) {
            if (!els[i].classList.contains('active')) {
                els[i].classList.add('active');
                all_active = false;
            }
        }
        if (all_active) {  // all were active, we deactivate them
            for (let i = 0; i < els.length; i++) {
                els[i].classList.remove('active');
            }
        }
    } else if (modifier && this.classList.contains('active')) {  // dont de-select when modifier is pressed
        // pass
    } else {
        this.classList.toggle('active');
    }
    window.last_selected = this.id;
    check_hover_enabled();
}

function image_info_quick(id="") {
    // display quick info in footer
    if (id == "") {
        const el = document.getElementById('imagegrid').querySelector('div.item:hover');
        if (el != null) {
            id = el.id;
        }
    }
    if (id != "") {
        document.getElementById('image_info_footer').innerText = window.items[id]["filename_original"] + ': ' + window.items[id]["channel_name"];
    }
}

function image_info_timeout(event, id="", histogram=false, timeout_ms=10) {
    if (id == "") {
        const id = this.id;
    }
    image_info_quick(id);

    // clear old timeout
    if (window.timeout_image_info != null) {
        clearTimeout(window.timeout_image_info);
    }

    // for main info we start a timeout when mouse enters the element - only after a short while julia will be asked to get all the info
    if (document.getElementById('sidebar_info').classList.contains("is-hidden") && get_view() != "zoom") {   // dont do anything if sidebar is not enabled or we are not in zoom-mode
        return;
    }

    window.timeout_image_info = window.setTimeout(function() {
        get_image_info(id, histogram);
    }, timeout_ms);
}

function image_info_quick_timeout_clear() {
    // clears timeout when mouse leaves the element
    if (get_view() != "grid") {  // do not do anything when we are not in grid mode
        return
    }

    if (window.timeout_image_info != null) {
        clearTimeout(window.timeout_image_info_quick);
    }

    // clear quick info (if no hover anymore)
    window.setTimeout(function () {
        if (document.getElementById('imagegrid').querySelector('div.item:hover') == null) {
            document.getElementById('image_info_footer').innerText = "";
        }
    }, 350);
}

function image_info_search_parameter() {
    if (document.getElementById('sidebar_info').classList.contains("is-hidden")) {   // dont do anything if sidebar is not enabled
        return;
    }
    document.querySelector(".dataTable-search .dataTable-input").focus();
    return false;
}

function add_image(id) {
    // adds image to the DOM
    const grid = document.getElementById('imagegrid');
    const t = document.getElementById('griditem');
    const el = t.content.firstElementChild.cloneNode(true)
    el.id = id;
    el.querySelector('img').src = file_url(id);
    grid.appendChild(el);
    el.addEventListener('click', select_item);
    el.addEventListener('dblclick', clear_all_active_mouse);  // with a modifier
    el.addEventListener('dblclick', toggle_imagezoom_mouse);  // only without a modifier
    el.addEventListener('mouseenter', image_info_timeout);
    el.addEventListener('mouseleave', image_info_quick_timeout_clear);
}

function update_image(id) {
    // updates the image to a new channel
    if (get_view() == "zoom" && window.zoom_last_selected == id) {
        next_item(0);  // updates the img src etc
    }
    document.getElementById(id).firstElementChild.firstElementChild.src = file_url(id);
}



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

function set_params(dir_res, dir_cache, dir_colorbars, filenames_colorbar, auto_save_minutes) {
    // set base directory for all relative paths (dir_res), global variable of dir cache, and continuous auto-save
    const el = document.createElement('base');
    el.href = dir_res;
    document.getElementsByTagName('head')[0].appendChild(el);

    window.dir_cache = dir_cache;
    window.dir_colorbars = dir_colorbars;
    window.filenames_colorbar = filenames_colorbar;
    window.auto_save_minutes = auto_save_minutes;
}

function load_images(images_parsed_arr, delete_previous = false) {  // here we use the array "images_parsed_arr", because we have to rpeserve order
    // load all images into the page

    // delete previous images
    if (delete_previous) {
        // remove all nodes
        let els = document.getElementById('imagegrid').getElementsByClassName('item');
        while (els.length > 0) {
            els[0].remove();
        }

        // delete saved items
        window.items = {};
    }

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

    if (delete_previous) {
        open_jobs(-1);  // this is interactively called only with delete_previous=true
    }
}

function update_images(images_parsed) {  // "images_parsed" is a dictionary here
    // updates images

    // let t1 = performance.now();
    // console.log("Update info get:" + (t1 - window.t0) + " ms.");

    for (let key in images_parsed) {
        window.items[key] = images_parsed[key];
        update_image(key);
        images_parsed[key].keywords.forEach((keyword) => {
            window.keywords_all.add(keyword);
        })
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

function show_info(id, info_json) {
    /// shows header data for an image
    if (window.image_info_id != id) return;  // there was some other event already

    // let t1 = performance.now();
    // console.log("info unparse:" + (t1 - window.t0) + " ms.");

    const filename_original = window.items[id].filename_original
    document.getElementById("image_info_filename").innerText = filename_original.substring(0, window.items[id].filename_original.length - 4);
    document.getElementById("image_info_channel_name").innerText = window.items[id].channel_name;
    document.getElementById("image_info_scansize").innerText =
        number_max_decimals(window.items[id].scansize[0], 3) + " x " + number_max_decimals(window.items[id].scansize[1], 3)
        + " " + window.items[id].scansize_unit;
    document.getElementById("image_info_background_correction").innerText = window.items[id].background_correction;
    document.getElementById("image_info_colorscheme").innerText = window.items[id].colorscheme;

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
            scrollY: "calc(var(--vh, 1vh) * 100 - 13.88rem)",
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

function saved_all() {
    // current state has been saved to disk
    open_jobs(-1);
}

function header_data(json) {
    // just for testing
    let t0 = performance.now();
    d = JSON.parse(json);
    let t1 = performance.now();
    console.log("JSON unparse:" + (t1 - t0) + " ms.");
}


// calling julia

function change_item(what, message, jump = 1) {
    console.log("change: " + what);
    ids = get_active_element_ids();

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

function re_parse_images() {
    // delete all images from DOM and re-parses them
    if (get_view() == "grid") {
        Blink.msg("re_parse_images", []);
        show_message("reloading.")
        open_jobs(1);
    }
}

function save_all(exit=false) {
    // saves the current state to disk
    console.log("save all")
    Blink.msg("save_all", [exit]);
    show_message("saving.")
    open_jobs(1);
}

