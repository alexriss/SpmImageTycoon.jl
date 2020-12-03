window.dir_cache = "";  // will be set by julia
window.items = {};  // dictionary with ids as keys and a dictionary of filenames as values

window.last_selected = -1  // last selected item

window.num_open_jobs = 0;  // how many julia jobs are open
window.timeout = null;  // timeout reference
window.timeout_image_info = null;  //timeout refrence for get_image_info function
window.image_info_id = -1;  // current image, for which data is displayed
window.datatable = null;  // holds the datatable


function toggle_sidebar() {
    let sidebar = document.getElementById('sidebar_grid');
    if (sidebar.style.display == "none") {
        sidebar.style.display = "block";
        get_image_info();  // update info of current or last image
    } else {
        sidebar.style.display = "none";
    }
}

function show_message(msg="") {
    // shows message in the footer
    if (window.timeout != null) {
        clearTimeout(window.timeout);
    }
    let el = document.getElementById('footer_message');
    el.innerText = msg;
    window.timeout = setTimeout(show_message, 2500);
}

function open_jobs(diff) {
    // tracks the number of open julia jobs and displays spinner as long as there are some
    window.num_open_jobs += diff;
    if (window.num_open_jobs > 0) {
        document.getElementById("spinner_title").classList.remove("hidden");
    } else {
        document.getElementById("spinner_title").classList.add("hidden");
    }
}

function clear_all_active() {
    // clears all active divs
    let grid = document.getElementById('imagegrid');
    let els = grid.getElementsByClassName('active');
    for (let i=els.length-1; i >= 0; i--) {
        els[i].classList.remove('active');
    }
    check_hover_enabled();
}

function toggle_all_active() {
    // toggles between select-all and select-none
    let grid = document.getElementById('imagegrid');
    let els = grid.querySelectorAll('.item:not(.active)');
    if (els.length == 0) {
        clear_all_active();
    } else {
        for (let i=0; i < els.length; i++) {
            els[i].classList.add('active');
        }
    }
    check_hover_enabled();
}

function get_active_element_ids() {
    // returns all active element ids
    // if any are selected (i.e active), then these are returned
    // otherwise if one is hovered, then this is returned
    // otherwise an empy list is returned
    let grid = document.getElementById('imagegrid');
    let els = grid.getElementsByClassName('active');

    if (els.length == 0) {
        els = grid.querySelectorAll('div.item:not(.active):hover')
    }

    if (els.length == 0) {
        return [];
    }

    els_id = new Array(els.length)
    for (let i=0; i < els.length; i++) {
      els_id[i] = els[i].id;
    }
    return els_id;
}

function check_hover_enabled() {
    // checks whether the magedrid should get the class hover_enabled
    // this is the case only if no active div.item elements are found
    // also writes the number of selected images into the footer.
    let grid = document.getElementById('imagegrid');
    let els = grid.getElementsByClassName('item active');
    if (els.length == 0) {
        grid.classList.add('hover_enabled');
    } else {
        grid.classList.remove('hover_enabled');
    }

    let el_num = document.getElementById('footer_num_images');
    el_num.innerText = els.length;
}

function select_item(event) {
    // selects one item or a bunch of items (if shift or ctrl is pressed)
    let modifier = (event.ctrlKey || event.shiftKey);
    let items = Array.from(this.parentNode.children);
    let idx = items.indexOf(this);
    let start = window.last_selected;
    if (modifier && window.last_selected != -1 && (idx != start)) {
        let end = idx;
        if (idx < window.last_selected) {
            start = idx;
            end = window.last_selected;
        }

        els = items.slice(start, end+1);
        let all_active = true;
        for (let i=0; i < els.length; i++) {
            if (!els[i].classList.contains('active')) {
                els[i].classList.add('active');
                all_active = false;
            }
        }
        if (all_active) {  // all were active, we deactivate them
            for (let i=0; i < els.length; i++) {
                els[i].classList.remove('active');
            }
        }
    } else if (modifier && this.classList.contains('active')) {  // dont de-select when modifier is pressed
        // pass
    } else { 
        this.classList.toggle('active');
    }
    window.last_selected = idx;
    check_hover_enabled();
}

function image_info_quick(id=-1) {
    // display quick info in footer
    if (id == -1) {
        let el =  document.getElementById('imagegrid').querySelector('div.item:hover');
        if (el != null) {
            id = el.id;
        }
    }
    if (id != -1) {
        document.getElementById('image_info_footer').innerText = window.items[id]["filename_original"] + ': ' + window.items[id]["channel_name"];
    }
}

function image_info_timeout() {
    image_info_quick(this.id);

    // for main info we start a timeout when mouse enters the element - only after a short while julia will be asked to get all the info
    if (document.getElementById('sidebar_grid').style.display == "none") {   // dont do anything is  sidebar is not enabled
        return;
    }
    let this_id = this.id;
    window.timeout_image_info = window.setTimeout(function() {
        get_image_info(this_id);
    }, 30);

}

function image_info_timeout_clear() {
    // clears timeout when mouse leaves the element
    if (window.timeout_image_info != null) {
        clearTimeout(window.timeout_image_info);
    }

    // clear quick info (if no hover anymore)
    window.setTimeout(function() {
        if (document.getElementById('imagegrid').querySelector('div.item:hover') == null) {
            document.getElementById('image_info_footer').innerText = "";
        }
     }, 350);
}

function image_info_search_parameter() {
    // starts timeout when mouse enters the element - after a short while ulia will be asked to get all the info
    if (document.getElementById('sidebar_grid').style.display == "none") {   // dont do anything is  sidebar is not enabled
        return;
    }
    document.querySelector(".dataTable-search .dataTable-input").focus();
    return false;
}

function add_image(id, filename) {
    // adds image to the DOM
    let grid = document.getElementById('imagegrid');
    let t = document.getElementById('griditem');
    let el = t.content.firstElementChild.cloneNode(true)
    // let el = document.createElement('div');
    el.id = id;
    // el.className = 'item';
    // filename = filename.replace(/\\/g, '/');
    // el.innerHTML = '<img src="file:///' + window.dir_cache + filename + '" /><span class="caption">' + filename + '</span>';
    el.querySelector('img').src = 'file:///' + window.dir_cache + filename;
    grid.appendChild(el);
    el.addEventListener('click', select_item);
    el.addEventListener('dblclick', clear_all_active);
    el.addEventListener('mouseenter', image_info_timeout);
    el.addEventListener('mouseleave', image_info_timeout_clear);
}

function update_image(id, filename) {
    // updates the image to a new channel
    document.getElementById(id).firstElementChild.src = 'file:///' + window.dir_cache + filename;
}


// called from julia

function load_page() {
    // loads the page contents
    let nodes = document.querySelectorAll('link[rel="import"]');  // blink.jl loads it into an html import
    let link = nodes[nodes.length - 1];
    document.body.innerHTML = link.import.querySelector('body').innerHTML

    document.body.classList.add('has-navbar-fixed-top');  // we need to do this here, because the base html file is served form blink

    // for dynamic css vh heights, see https://css-tricks.com/the-trick-to-viewport-units-on-mobile/
    let vh = window.innerHeight * 0.01;
    document.documentElement.style.setProperty('--vh', `${vh}px`);
    window.addEventListener('resize', () => {
        // We execute the same script as before
        let vh = window.innerHeight * 0.01;
        document.documentElement.style.setProperty('--vh', `${vh}px`);
    });
}

function set_dir_cache(dir_cache) {
    // stes the global variable of dir cache
    window.dir_cache = dir_cache;
}

function set_base_href(dir_res) {
    // sets a base directory for all relative paths
    let el = document.createElement('base');
    el.href = dir_res;
    document.getElementsByTagName('head')[0].appendChild(el);    
}

function load_images(ids, filenames, filenames_original, channel_names, background_corrections) {
    // loads images
    for (let i=0; i < ids.length; i++) {
        add_image(ids[i], filenames[i]);
        window.items[ids[i]] = {
            filename_original: filenames_original[i],
            filename_display: filenames[i],
            channel_name: channel_names[i],
            background_correction: background_corrections[i],
        };
    }
}

function update_images(ids, filenames, channel_names, background_corrections) {
    // updates images
    for (let i=0; i < ids.length; i++) {
        update_image(ids[i], filenames[i]);
        window.items[ids[i]]['filename_display'] = filenames[i];
        window.items[ids[i]]['channel_name'] = channel_names[i];
        window.items[ids[i]]['backgound_correction'] = background_corrections[i];
    }

    // update image info
    image_info_quick();
    get_image_info();

    open_jobs(-1);
}

function show_info(id, info_main, info_json) {
    /// shows header data for an image
    if (window.image_info_id != id)  return;  // there was some other event already

    let t1 = performance.now();
    console.log("info unparse:" + (t1 - window.t0) + " ms.");

    document.getElementById("image_info_filename").innerText = info_main["filename"];
    document.getElementById("image_info_channel_name").innerText = info_main["channel_name"];
    document.getElementById("image_info_scansize").innerText = info_main["scansize"] + " " + info_main["scansize_unit"];
    document.getElementById("image_info_background_correction").innerText = info_main["background_correction"];

    if (window.datatable == null) {
        window.datatable = new simpleDatatables.DataTable("#image_info", {
            searchable: true,
            // fixedHeight: true,
            paging: false,
            scrollY: "calc(var(--vh, 1vh) * 100 - 204px)",
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
    t1 = performance.now();
    console.log("info unparse (create table):" + (t1 - window.t0) + " ms.");
}

function header_data(json) {
    // just for testing
    let t0 = performance.now();
    d = JSON.parse(json);
    let t1 = performance.now();
    console.log("JSON unparse:" + (t1 - t0) + " ms.");
}


// calling julia

function change_channel() {
    console.log("change channel");
    els_id = get_active_element_ids();
    if (els_id.length > 0) {
        Blink.msg("grid_item", ["next_channel", els_id]);
    }
    show_message("change channel.")
    open_jobs(1);
}

function change_direction() {
    console.log("change direction");
    els_id = get_active_element_ids();
    if (els_id.length > 0) {
        Blink.msg("grid_item", ["next_direction", els_id]);
    }
    show_message("change direction.")
    open_jobs(1);
}

function change_background_correction() {
    console.log("change background correction");
    els_id = get_active_element_ids();
    if (els_id.length > 0) {
        Blink.msg("grid_item", ["next_background_correction", els_id]);
    }
    show_message("change background.")
    open_jobs(1);
}

function get_image_info(id=-1) {
    // gets info (header data) for the current image
    console.log("get info");
    window.t0 = performance.now();

    if (id == -1) {
        let el =  document.getElementById('imagegrid').querySelector('div.item:hover');
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
    if (id != -1) {
        window.image_info_id = id;
        Blink.msg("grid_item", ["get_info", [id]]);
    }
}



// keyboard events etc

key_commands = {
    c: change_channel,
    d: change_direction,
    b: change_background_correction,
    a: toggle_all_active,
    m: toggle_sidebar,
    p: image_info_search_parameter,
}

// for debugging, F5 for reload, F12 for dev tools
document.addEventListener("keydown", function (e) {
    if (e.target.nodeName == "INPUT" || e.target.nodeName == "TEXTAREA" || e.target.isContentEditable) {
        if (e.key == "Escape") e.target.blur();
        return;
    }
    if (e.key == "F12") {  // F12
		require('electron').remote.getCurrentWindow().toggleDevTools();
    } else if (e.key in key_commands) {
        key_commands[e.key]();
        e.preventDefault();
        e.stopPropagation();
    }
});
