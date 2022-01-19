window.dir_res = "";  // resources directory. sey by julia
window.dir_cache = "";  // cache directory, set by julia
window.dir_data = "";  // directory with all data
window.dir_colorbars = "";  // colorbars are saved here, set by julia
window.filenames_colorbar = {};  // dictionary specifying the filenames for the colorbars, set by julia
window.items = {};  // dictionary with ids as keys and a dictionary of filenames as values
window.bottomleft = [];  // bottom left of overall scan range
window.topright = [];   // top right of overall scan range

window.last_directories = [];  // array of last directories used (set by julia)
window.auto_save_minutes = 0  // auto-save every n minutes (set by julia)
window.overview_max_images = 0  // maximum number of images to display in the filter overview (set by julia)

window.space_pressed = false;  // true if user is holding space down (for dragging etc)

window.last_selected = "";  // last selected item
window.zoom_control_setup = false;  // whether drag/zoom for zoomview is setup
window.zoom_last_selected = "";  // last selected image for zoom
window.sidebar_imagezoomtools = false;  // sidebar in imagezoom mode is visible
window.grid_last_scrolltop = 0;  // last y-scroll position in grid view (does not seem to be properly restored when hiding/showing grid view)

window.line_profile_object = null;  // hold the line profile object

window.histogram_object = null;  // holds the histogram object

window.spectrum_plot_object = null;  // hold the spectrum plot object

window.filter_overview_selection_object = null;  // holds the selection object for overview filter
window.filter_overview_selecting = false;  // user is currently making a selection

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

window.timeout_filter = null;  // timeout refrence for filter function
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
         "?" + item.channel_name + "_" + item.channel2_name + "_" + item.background_correction + "_" + item.colorscheme +
         "_" + item.scan_direction + 
         "_range_" + item.channel_range_selected;  // to prevent caching and force reload
}

function file_url_colorbar(id) {
    // returns the colorbar url
    const item = window.items[id];
    return 'file:///' + window.dir_colorbars + window.filenames_colorbar[item.colorscheme];
}

function insertAfter(newNode, referenceNode) {
    // inserts node after a certain node (will also handle if the referenceNode is the last node)
    referenceNode.parentNode.insertBefore(newNode, referenceNode.nextSibling);
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

function reset_all() {
    // resets view and all selections etc
    window.last_selected = "";
    window.zoom_last_selected = "";
    if (window.timeout != null) {
        clearTimeout(window.timeout);
        window.timeout = null;
    }
    if (window.timeout_image_info != null) {
        clearTimeout(window.timeout_image_info);
        window.timeout_image_info = null;
    }
    if (window.timeout_image_info_quick != null) {
        clearTimeout(window.timeout_image_info_quick);
        window.timeout_image_info_quick = null;
    }
    window.image_info_id = "";
    document.getElementById("sidebar_content_none").classList.remove("is-hidden");
    document.getElementById("sidebar_content").classList.add("is-hidden");

    show_message(); // empty footer message
    standard_view();
}

function toggle_pixelated() {
    // toggles pixelated vs interpolated display of images in zoom mode
    let img_zoom = document.getElementById("imagezoom_image");
    if (img_zoom.classList.contains("pixelated")) {
        img_zoom.classList.remove("pixelated");
    } else {
        img_zoom.classList.add("pixelated");
    }
}

function toggle_help() {
    // toggle help modal
    if (document.getElementById("modal_help").classList.contains("is-active")) {
        document.getElementById("modal_help").classList.remove("is-active");
    } else {
        document.getElementById("modal_help").classList.add("is-active");
    }
}

function toggle_about() {
    // toggle help modal
    if (document.getElementById("modal_about").classList.contains("is-active")) {
        document.getElementById("modal_about").classList.remove("is-active");
    } else {
        document.getElementById("modal_about").classList.add("is-active");
    }
}

function toggle_error() {
    // toggle error modal
    if (document.getElementById("modal_error").classList.contains("is-active")) {
        document.getElementById("modal_error").classList.remove("is-active");
    } else {
        document.getElementById("modal_error").classList.add("is-active");
    }
}

function toggle_dev_tools() {
    // toggles dev tools
    require('electron').remote.getCurrentWindow().toggleDevTools();
}

function toggle_start_project(target="project", save=false) {
    // toggles between project page and start page
    if (target == "re-project") {  // undo close project
        if (window.dir_data != "") {
            target = "project";
        } else {
            return;
        }
    }
    if (save) {
        save_all(); // the function does not save, though, if get_view() == "start" (that's ok here)
    }

    if (target == "project") {
        reset_all();
        document.getElementById("page_start").classList.add("is-hidden");
        document.getElementById("page_project").classList.remove("is-hidden");
        document.getElementById("footer_project").classList.remove("is-hidden");
        start_page_logo_spin(false);
    } else {
        const template_last_dir = document.getElementById("page_start_last_dir");
        const container_last_dir = document.getElementById("page_start_last_dir_container");
        let els = container_last_dir.getElementsByClassName('last_directory');
        while (els.length > 0) {
            els[0].remove();
        }
        // re-populate
        window.last_directories.forEach(last_dir => {
            let el_last_dir = template_last_dir.content.firstElementChild.cloneNode(true);
            el_last_dir.getElementsByClassName("page_start_last_dir_name")[0].innerText = last_dir;
            el_last_dir.classList.add("last_directory");
            container_last_dir.appendChild(el_last_dir);
            el_last_dir.addEventListener('click', function() {
                load_directory(last_dir);
            });
        });

        if (container_last_dir.getElementsByClassName('last_directory').length == 0) {  // don't show header if there are no recent directories
            document.getElementById("page_start_last_dir_header").classList.add("is-hidden");
        } else {
            document.getElementById("page_start_last_dir_header").classList.remove("is-hidden");
        }
        
        document.getElementById("page_start_open_directory").classList.remove("is-hidden");
        document.getElementById("page_start_load_error").classList.add("is-hidden");
        document.getElementById("page_start_progress").classList.add("is-hidden");

        document.getElementById("page_project").classList.add("is-hidden");
        document.getElementById("footer_project").classList.add("is-hidden");
        document.getElementById("page_start").classList.remove("is-hidden");
        start_page_logo_spin(true);
    }
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

    if (what == "filter") {
        if (!sidebar.classList.contains("is-hidden") && window.filter_overview_selection_object === null) {
            filter_overview_setup();  // will set up the selection library
            zoom_drag_filter_overview_setup(document.getElementById("filter_overview_container")); // set up zoom and drag for filter overview
        }
    }
}

function toggle_sidebar_imagezoomtools(restore_previous=false) {
    // toggles sidebar in imagezoom mode
    let sidebar = document.getElementById('sidebar_imagezoomtools');

    if (restore_previous && get_view() == "zoom") {
        if (window.sidebar_imagezoomtools) {
            if (sidebar.classList.contains("is-hidden")) {
                sidebar.classList.remove("is-hidden");
            }
        } else {
            if (!sidebar.classList.contains("is-hidden")) {
                sidebar.classList.add("is-hidden");
            }
        }
    } else if (get_view() == "zoom") {
        if (sidebar.classList.contains("is-hidden")) {
            sidebar.classList.remove("is-hidden");
            window.sidebar_imagezoomtools = true;
        } else {
            sidebar.classList.add("is-hidden");
            window.sidebar_imagezoomtools = false;
        }
    } else {
        if (!sidebar.classList.contains("is-hidden")) {
            sidebar.classList.add("is-hidden");
        }
    }
    if (!sidebar.classList.contains("is-hidden") && window.line_profile_object !== null) {
        window.line_profile_object.setup();  // will set up or remove event handlers
    }
}

function standard_view() {
    // sets standard view, for instance when a new project is opened
    toggle_imagezoom("grid");
    toggle_sidebar("info", true);
}

function get_view() {
    if (document.getElementById("modal_error").classList.contains("is-active")) {
        return "error";
    } else if (document.getElementById("modal_help").classList.contains("is-active")) {
        return "help";
    } else if (document.getElementById("modal_about").classList.contains("is-active")) {
        return "about";
    } else if (!document.getElementById("page_start").classList.contains("is-hidden")) {
        if (document.getElementById("page_start_open_directory").classList.contains("is-hidden")) {
            return "start_loading";
        } else {
            return "start";
        }
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
    const gridsub = document.getElementById('imagegrid_container_sub');
    const zoom = document.getElementById('zoomview_container');
    const footer_num_images_container = document.getElementById('footer_num_images_container');

    if (get_view() == "help") {
        toggle_help();
    } else if (get_view() == "keywords") {
        toggle_keywords_dialog();
    } else if (get_view() == "zoom" || target_view == "grid") {
        zoom.classList.add("is-hidden");
        grid.classList.remove("is-hidden");
        footer_num_images_container.classList.remove("is-invisible");
        image_info_quick_timeout_clear();  // if we leave zoom-mode, we might need to get rid of the quick image info (if mouse is not hovering anything)
        toggle_sidebar_imagezoomtools();  // get rid of imagezoomtools
        gridsub.scrollTop = window.grid_last_scrolltop;
    } else {
        let el = grid.querySelector('div.item:hover');
        if (el != null) {
            window.grid_last_scrolltop = gridsub.scrollTop;
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
            toggle_sidebar_imagezoomtools(restore_previous=true);
        }
    }
}

function imagezoom_size_adjust() {
    // adjusts size of imagezoom
    let el = document.getElementById('imagezoom_content');
    let w = el.clientWidth;
    if (w == 0) {  // not visible
        return;
    }
    let h = el.clientHeight;
    let el_img = document.getElementById("imagezoom_image");
    let w_img = el_img.naturalWidth;
    let h_img = el_img.naturalHeight;

    if (w_img > 0 && h_img > 0) {  // sometimes the image is not ready yet
        if (w_img/h_img >= w/h) {
            el_img.classList.add("fullwidth");
            el_img.classList.remove("fullheight");
        } else {
            el_img.classList.remove("fullwidth");
            el_img.classList.add("fullheight");
        }
    }
    if (window.line_profile_object !== null) {
        window.line_profile_object.setup();  // will set up size of canvas
    }
}

function show_message(msg = "") {
    // shows message in the footer
    if (window.timeout != null) {
        // clearTimeout(window.timeout);
    }
    let el = document.getElementById('footer_message');
    el.innerText = msg;
    if (msg != "") {
        window.timeout = setTimeout(show_message, 2500);
    }
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

function toggle_all_active(ignore_filter_status=false) {
    // toggles between select-all and select-none
    if (get_view() != "grid") {
        return;
    }

    if (ignore_filter_status) {
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

function get_active_element_ids(only_current=false, all_visible_if_none_selected=false) {
    // returns all active element ids
    // for zoom view, an array with this one element is returned
    // for grid view, if any are selected (i.e active), then these are returned (irrespective of filter/hidden status)
    //    .. unless only_current is true, then only this is returned
    // otherwise if one is hovered, then this is returned
    // otherwise an empty array is returned
    // if all_visible_if_none_selected is true, then all not-hidden will be returned (if none are selected)

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
        if (all_visible_if_none_selected) {
            els = grid.querySelectorAll('div.item:not(.hidden)');
        } else {
            els = grid.querySelectorAll('div.item:not(.active):hover');
        }
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
    // checks whether the imagedrid should get the class hover_enabled
    // this is the case only if no active div.item elements are found
    // also writes the number of selected images into the footer.
    // also adds images to the filter_overview window
    const grid = document.getElementById('imagegrid');
    const els = grid.getElementsByClassName('item active');
    const overview = document.getElementById('filter_overview');

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

    // filter overview
    const els_with_background = Array.from(overview.getElementsByClassName("with_background"));
    if (els.length == 0 || els.length > window.overview_max_images) {  // remove all backgrounds
        for (let i=0; i < els_with_background.length; i++) {
            els_with_background[i].firstElementChild.style.backgroundImage = "none";
            els_with_background[i].classList.remove("with_background");
        }
    } else {  // update images
        // remove all other images
        const prefix = "filter_overview_item_";
        const prefix_length = prefix.length;
        const ids = Array.from(els).map(function(el) {
            return el.id;
        });

        for (let i=0; i < els_with_background.length; i++) {
            if (!ids.includes(els_with_background[i].id.substring(prefix_length))) {  // we cut off the prefix
                els_with_background[i].firstElementChild.style.backgroundImage = "none";
                els_with_background[i].classList.remove("with_background");
            }
        }
        for (let i=0; i<ids.length;i++) {
            let el = document.getElementById(prefix + ids[i]);
            if (window.items[ids[i]].type == "SpmGridImage") {
                el.firstElementChild.style.backgroundImage = 'url("' + file_url(ids[i]).replace(/\\/g, "/") + '")';  // we seem to have to replace backward for forward slashed for the css
            }
            el.classList.add("with_background");
        }        
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
        window.image_info_id = el.id;
        window.zoom_last_selected = el.id;

        if (window.items[el.id].type == "SpmGridImage") {
            document.getElementById('imagezoom_image').src = file_url(el.id)
            document.getElementById('imagezoom_colorbar').src = file_url_colorbar(el.id);

            document.getElementById("zoomview_container_image").classList.remove("is-hidden");
            document.getElementById("zoomview_container_spectrum").classList.add("is-hidden");

            if (window.histogram_object === null) {
                window.histogram_object = new Histogram();
            }
            window.histogram_object.set_range_initial(window.items[el.id].channel_range, window.items[el.id].channel_range_selected, window.items[el.id].channel_unit);

            if (window.line_profile_object === null) {
                window.line_profile_object = new LineProfile(document.getElementById("imagezoom_canvas"), document.getElementById('imagezoom_image'));
            }
            window.line_profile_object.setup(new_image=true);
            imagezoom_size_adjust();
        } else {
            document.getElementById("zoomview_container_image").classList.add("is-hidden");
            document.getElementById("zoomview_container_spectrum").classList.remove("is-hidden");

            if (window.spectrum_plot_object === null) {
                window.spectrum_plot_object = new SpectrumPlot(document.getElementById("spectrumzoom_plot_container"));
            }
            window.spectrum_plot_object.setup();
        }

        image_info_timeout(null, el.id, zoomview=true, timeout_ms=30);
    }
}

function scroll_to_selected(next=true) {
    // scrolls to next/previous selected item

    if (get_view() != "grid") {
        return;
    }

    const items = Array.from(document.querySelectorAll('#imagegrid .item:not(.is-hidden).active'));
    if (items.length == 0) {
        return;
    }
    const gridsub = document.getElementById('imagegrid_container_sub');
    const curr = gridsub.scrollTop;
    let item_scrollto = null;
    if (next) {
        for (let i=0; i<items.length; i++) {
            if (items[i].offsetTop > curr + 12) {
                item_scrollto = items[i];
                break;
            }
        }
        if (item_scrollto === null) {  // wrap around
            item_scrollto = items[0];
        }
    } else {
        for (let i=items.length-1; i>=0; i--) {
            if (items[i].offsetTop < curr) {
                item_scrollto = items[i];
                break;
            }
        }
        if (item_scrollto === null) {  // wrap around
            item_scrollto = items[items.length - 1];
        }
    }
    gridsub.scrollTop = item_scrollto.offsetTop - 10;
}

function select_item(event) {
    // selects one item or a bunch of items (if shift or ctrl is pressed)

    if (get_view() != "grid") {
        return;
    }

    const modifier = event.shiftKey;
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
        let str_footer = window.items[id]["filename_original"] + ': ' + window.items[id]["channel_name"];
        if (window.items[id]["channel2_name"].length > 0) {
            str_footer += " vs. " + window.items[id]["channel2_name"];
        }
        document.getElementById('image_info_footer').innerText = str_footer;

        // hover in filter overview (highlight will be disabled in image_info_quick_timeout_clear)
        const highlighted = document.getElementById("filter_overview").getElementsByClassName("highlight");
        for (let i=0; i<highlighted.length; i++) {
            highlighted[i].classList.remove('highlight');
        }

        document.getElementById("filter_overview_item_" + id).classList.add("highlight");
    }
}

function image_info_timeout(event, id="", zoomview=false, timeout_ms=10) {
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
        get_image_info(id, zoomview);
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
            const highlighted = document.getElementById("filter_overview").getElementsByClassName("highlight");
            for (let i=0; i<highlighted.length; i++) {
                highlighted[i].classList.remove('highlight');
            }    
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

function add_image(id, id_after=null) {
    // adds image to the DOM
    const grid = document.getElementById('imagegrid');
    const t = document.getElementById('griditem');
    const el = t.content.firstElementChild.cloneNode(true)
    el.id = id;
    el.querySelector('img').src = file_url(id);
    if (id_after === null) {
        grid.append(el);
    } else if (id_after === "") {
        grid.prepend(el);
    } else {
        insertAfter(el, document.getElementById(id_after));
    }
    
    el.addEventListener('click', select_item);
    el.addEventListener('dblclick', clear_all_active_mouse);  // with a modifier
    el.addEventListener('dblclick', toggle_imagezoom_mouse);  // only without a modifier
    el.addEventListener('mouseenter', image_info_timeout);
    el.addEventListener('mouseleave', image_info_quick_timeout_clear);

    // add to overview as well
    add_image_overview(id);
}

function add_image_overview(id) {
    // adds image to overview in filter sidebar
    const overview = document.getElementById("filter_overview");
    const t = document.getElementById('filter_overview_item_template');
    const el = t.content.firstElementChild.cloneNode(true)
    el.id = "filter_overview_item_" + id;

    let wh_nm = [0.0, 0.0];
    
    // set position
    if (window.items[id].type == "SpmGridImage") {
        wh_nm = [
            window.items[id].scansize[0],
            window.items[id].scansize[1]
        ];
    } else {  // spectrum
        el.classList.add("filter_overview_dot"); // spectra will be displayed as dots
    }
    const wh_rel = filter_overview_nm_to_rel(wh_nm, coords=false);  // defined in GUI_filter_overview.js
    const topleft_nm = [
        window.items[id].center[0] - wh_nm[0] / 2,
        window.items[id].center[1] + wh_nm[1] / 2  // y in nm goes from bottom to top
    ];
    const topleft_rel = filter_overview_nm_to_rel(topleft_nm);
    el.style.left = "" + topleft_rel[0]*100 + "%";
    el.style.top = "" + topleft_rel[1]*100 + "%";
    if (window.items[id].type == "SpmGridImage") {
        el.style.width = "" + wh_rel[0]*100 + "%";
        el.style.height = "" + wh_rel[1]*100 + "%";  // for spectra there is no width and height, it is done via border

        const angle = window.items[id].angle;
        if (angle != 0) {
            el.style.transform = "rotate("+ angle +"deg)";
        }
    }

    overview.appendChild(el);
}

function update_image(id) {
    // updates the image to a new channel
    if (get_view() == "zoom" && window.zoom_last_selected == id) {
        next_item(0);  // updates the img src etc
    }
    document.getElementById(id).firstElementChild.firstElementChild.src = file_url(id);
    // images in overview
    const el = document.getElementById("filter_overview_item_" + id);
    if (el.classList.contains("with_background")) {
        if (window.items[id].type == "SpmGridImage") {
            el.firstElementChild.style.backgroundImage = 'url("' + file_url(id).replace(/\\/g, "/") + '")';  // we seem to have to replace backward for forward slashed for the css
        }
    }

}

function escape_handler() {
    // handles pressing of Escape
    send_cancel(); // to julia (only has an effect when images are parsed, but doesnt hurt otherwise)
    toggle_imagezoom("grid");  // from imagezoom (only when in imagezoom mode, but doesnt hurt otherwise)
}

function open_in_explorer(what="") {
    // opens and selects file in system explorer
    const ids = get_active_element_ids(only_current=true);
    if (ids.length > 0) {
        const item = window.items[ids[0]];
        if (what == "image") {
            file_path = window.dir_cache + item.filename_display;  // generated image
        } else {
            file_path = window.dir_data + item.filename_original;  // original file
        }
        const {shell} = require('electron');
        shell.showItemInFolder(file_path);
    }
}