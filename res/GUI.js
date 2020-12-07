window.dir_res = "";  // resources directory
window.dir_cache = "";  // will be set by julia
window.items = {};  // dictionary with ids as keys and a dictionary of filenames as values

window.last_selected = -1;  // last selected item
window.last_scroll_grid = 0;  // last scroll position in grid view
window.zoom_control_setup = false;  // whether drag/zoom for zoomview is setup
window.zoom_last_selected = -1;  // last selected image for zoom

window.num_open_jobs = 0;  // how many julia jobs are open
window.timeout = null;  // timeout reference
window.timeout_image_info = null;  //timeout refrence for get_image_info function
window.image_info_id = -1;  // current image, for which data is displayed
window.datatable = null;  // holds the datatable


function show_help() {
    // toggle  help modal
    if (document.getElementById("modal_help").classList.contains("is-active")) {
        document.getElementById("modal_help").classList.remove("is-active");
    } else {
        document.getElementById("modal_help").classList.add("is-active");
    }
}

function toggle_sidebar(show_sidebar=false) {
    // toggles sidebar
    let sidebar = document.getElementById('sidebar_grid');
    if (sidebar.classList.contains("is-hidden") || show_sidebar) {
        sidebar.classList.remove("is-hidden");
        get_image_info();  // update info of current or last image
    } else {
        sidebar.classList.add("is-hidden");
    }
}

function get_view() {
    if (document.getElementById("modal_help").classList.contains("is-active")) {
        return "help";
    } else if (document.getElementById('imagegrid_container').classList.contains("is-hidden")) {
        return "zoom";
    } else {
        return "grid";
    }
}

function toggle_imagezoom_mouse(event) {
    // switches to imagezoom mode via a mouse event (only if no modifier is pressed)
    if (!event.ctrlKey && !event.shiftKey) {
        toggle_imagezoom("zoom")
    }
}

function toggle_imagezoom(target_view = "") {
    // toggles between grid and imagezoom views

    const grid = document.getElementById('imagegrid_container');
    const zoom = document.getElementById('imagezoom_container');
    const footer_num_images_container = document.getElementById('footer_num_images_container');

    if (get_view() == "help") {
        show_help();
    } else if (get_view() == "zoom" || target_view == "grid") {
        zoom.classList.add("is-hidden");
        grid.classList.remove("is-hidden");
        footer_num_images_container.classList.remove("is-invisible")
        window.scrollTo(0, window.last_scroll_grid);
    } else {
        let el = grid.querySelector('div.item:hover');
        if (el != null) {
            window.last_scroll_grid = window.scrollY;
            grid.classList.add("is-hidden");
            zoom.classList.remove("is-hidden");
            footer_num_images_container.classList.add("is-invisible")

            window.image_info_id = el.id;  // should be set already, but just to make sure
            get_image_info(el.id);  // should also not be necessary

            const zoom_content = document.getElementById('imagezoom_content');
            if (!window.zoom_control_setup) {
                zoom_drag_setup(zoom_content);
                window.zoom_control_setup = true;
            }
            if (window.zoom_last_selected != el.id) {
                document.getElementById('imagezoom_image').src = 'file:///' + window.dir_cache + window.items[el.id]["filename_display"];
                zoom_drag_reset(zoom_content);
            }
            window.zoom_last_selected = el.id;
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

function open_jobs(diff) {
    // tracks the number of open julia jobs and displays spinner as long as there are some
    window.num_open_jobs += diff;
    if (window.num_open_jobs > 0) {
        document.getElementById("spinner_title").classList.remove("is-invisible");
    } else {
        document.getElementById("spinner_title").classList.add("is-invisible");
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

function toggle_all_active() {
    // toggles between select-all and select-none
    if (get_view() != "grid") {
        return;
    }
    const grid = document.getElementById('imagegrid');
    const els = grid.querySelectorAll('.item:not(.active)');
    if (els.length == 0) {
        clear_all_active();
    } else {
        for (let i = 0; i < els.length; i++) {
            els[i].classList.add('active');
        }
    }
    check_hover_enabled();
}

function get_active_element_ids() {
    // returns all active element ids
    // for zoom view, an array with this one element is returned
    // for grid view, if any are selected (i.e active), then these are returned
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

    if (els.length == 0) {
        els = grid.querySelectorAll('div.item:not(.active):hover')
    }

    if (els.length == 0) {
        return [];
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

    const el_num = document.getElementById('footer_num_images');
    el_num.innerText = els.length;
}

function next_item(jump) {
    // jumps a number of items forward or backward (only in zoom mode currently)
    if (get_view() != "zoom") {
        return;
    }

    let el = document.getElementById(window.zoom_last_selected);
    let elnext = el;
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
            break;
        } else if (elnext.classList.contains("is-hidden") || !elnext.classList.contains("item")) {    // do not count hidden items
            i = i - Math.sign(jump);
        }

        el = elnext;
    }
    if (el.id in window.items) {
        document.getElementById('imagezoom_image').src = 'file:///' + window.dir_cache + window.items[el.id]["filename_display"];
        window.image_info_id = el.id;
        window.zoom_last_selected = el.id;
        get_image_info(el.id);
    }
}

function select_item(event) {
    // selects one item or a bunch of items (if shift or ctrl is pressed)

    if (get_view() != "grid") {
        return;
    }

    const modifier = (event.ctrlKey || event.shiftKey);
    const items = Array.from(this.parentNode.children);
    const idx = items.indexOf(this);
    let start = window.last_selected;
    if (modifier && window.last_selected != -1 && (idx != start)) {
        let end = idx;
        if (idx < window.last_selected) {
            start = idx;
            end = window.last_selected;
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
    window.last_selected = idx;
    check_hover_enabled();
}

function image_info_quick(id = -1) {
    // display quick info in footer
    if (id == -1) {
        const el = document.getElementById('imagegrid').querySelector('div.item:hover');
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
    const this_id = this.id;
    window.timeout_image_info = window.setTimeout(function () {
        get_image_info(this_id);
    }, 10);

}

function image_info_timeout_clear() {
    // clears timeout when mouse leaves the element
    if (window.timeout_image_info != null) {
        clearTimeout(window.timeout_image_info);
    }

    // clear quick info (if no hover anymore)
    window.setTimeout(function () {
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
    const grid = document.getElementById('imagegrid');
    const t = document.getElementById('griditem');
    const el = t.content.firstElementChild.cloneNode(true)
    // let el = document.createElement('div');
    el.id = id;
    // el.className = 'item';
    // filename = filename.replace(/\\/g, '/');
    // el.innerHTML = '<img src="file:///' + window.dir_cache + filename + '" /><span class="caption">' + filename + '</span>';
    el.querySelector('img').src = 'file:///' + window.dir_cache + filename;
    grid.appendChild(el);
    el.addEventListener('click', select_item);
    el.addEventListener('dblclick', clear_all_active_mouse);  // with a modifier
    el.addEventListener('dblclick', toggle_imagezoom_mouse);  // only without a modifier
    el.addEventListener('mouseenter', image_info_timeout);
    el.addEventListener('mouseleave', image_info_timeout_clear);
}

function update_image(id, filename) {
    // updates the image to a new channel
    if (get_view() == "zoom" && window.zoom_last_selected == id) {
        document.getElementById('imagezoom_image').src = 'file:///' + window.dir_cache + filename;
    }
    document.getElementById(id).firstElementChild.firstElementChild.src = 'file:///' + window.dir_cache + filename;
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

function set_dir_cache(dir_cache) {
    // stes the global variable of dir cache
    window.dir_cache = dir_cache;
}

function set_base_href(dir_res) {
    // sets a base directory for all relative paths
    const el = document.createElement('base');
    el.href = dir_res;
    document.getElementsByTagName('head')[0].appendChild(el);
}

function load_images(ids, images_parsed, delete_previous = false) {
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

        open_jobs(-1);  // this is interactively called only with delete_previous=true
    }

    // loads new images
    for (let i = 0; i < ids.length; i++) {
        add_image(ids[i], images_parsed[i].filename_display);
        window.items[ids[i]] = images_parsed[i];
    }
}

function update_images(ids, images_parsed) {
    // updates images
    for (let i = 0; i < ids.length; i++) {
        update_image(ids[i], images_parsed[i].filename_display);
        window.items[ids[i]] = images_parsed[i];
    }

    // update image info
    image_info_quick();
    get_image_info();

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
    document.getElementById("image_info_scansize").innerText = window.items[id].scansize[0] + " x " + window.items[id].scansize[1] + " " + window.items[id].scansize_unit;
    document.getElementById("image_info_background_correction").innerText = window.items[id].background_correction;
    document.getElementById("image_info_colorscheme").innerText = window.items[id].colorscheme;

    const rating = window.items[id].rating;
    if (rating > 0) {
        document.getElementsByName("image_info_rating")[rating -1].checked = true;
    } else {
        document.getElementsByName("image_info_rating").forEach((el) => {
            el.checked = false;
        })
    }

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
    // t1 = performance.now();
    // console.log("info unparse (create table):" + (t1 - window.t0) + " ms.");
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

    if (get_view() == "zoom") {
        full_resolution = true;
    } else {
        full_resolution = false;
    }

    if (ids.length > 0) {
        Blink.msg("grid_item", ["next_" + what, ids, jump, full_resolution]);
        open_jobs(1);
        show_message(message)
    }
}

function get_image_info(id = -1) {
    // gets info (header data) for the current image

    // console.log("get info");
    // window.t0 = performance.now();
    if (id == -1) {
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
    if (id != -1) {
        window.image_info_id = id;
        Blink.msg("grid_item", ["get_info", [id]]);
    }
}

function re_parse_images(message) {
    // delete all images from DOM and re-parses them
    if (get_view() == "grid") {
        Blink.msg("re_parse_images", []);
        show_message(message)
        open_jobs(1);
    }
}

function set_rating(rating, only_current=false) {
    // sets the rating for items.
    // if "only_current" is true, then only set the rating for the item displayed int he sidebar.

    let ids = [];
    if (only_current) {
        if (window.image_info_id == -1) {
            return;
        }
        ids = [window.image_info_id];
    } else {
        ids = get_active_element_ids();
    }

    if (ids.length > 0) {
        Blink.msg("grid_item", ["set_rating", ids, rating]);
        open_jobs(1);  // julia will then set the radiobox
    }
}



// keyboard events etc

key_commands = {
    c: { command: change_item, args: ["channel", "change channel."] },
    d: { command: change_item, args: ["direction", "change direction."] },
    b: { command: change_item, args: ["background_correction", "change background."] },
    f: { command: change_item, args: ["colorscheme", "change colorscheme."] },
    i: { command: change_item, args: ["inverted", "invert colorscheme."] },
    C: { command: change_item, args: ["channel", "change channel.", -1] },
    D: { command: change_item, args: ["direction", "change direction.", -1] },
    B: { command: change_item, args: ["background_correction", "change background.", -1] },
    F: { command: change_item, args: ["colorscheme", "change colorscheme.", -1] },
    I: { command: change_item, args: ["inverted", "invert colorscheme."] },
    a: { command: toggle_all_active, args: [] },
    m: { command: toggle_sidebar, args: [] },
    z: { command: toggle_imagezoom, args: [] },
    0: { command: set_rating, args: [0] },
    1: { command: set_rating, args: [1] },
    2: { command: set_rating, args: [2] },
    3: { command: set_rating, args: [3] },
    4: { command: set_rating, args: [4] },
    5: { command: set_rating, args: [5] },
    p: { command: image_info_search_parameter, args: [] },
    h: { command: show_help, args: [] },
    "?": { command: show_help, args: [] },
    "/": { command: show_help, args: [] },
    F1: { command: show_help, args: [] },
    ArrowRight: { command: next_item, args: [1] },
    ArrowLeft: { command: next_item, args: [-1] },
    Escape: { command: toggle_imagezoom, args: ["grid"] },
    F5: { command: re_parse_images, args: [] },
}

// for debugging, F5 for reload, F12 for dev tools
document.addEventListener("keydown", function (event) {
    if (get_view() == "help") {    // only certain buttons allowed
        if (["Escape", "?", "/", "h", "F1"].includes(event.key)) {
            show_help();
        }
        return;
    }
    if (event.target.nodeName == "INPUT" || event.target.nodeName == "TEXTAREA" || event.target.isContentEditable) {
        if (event.key == "Escape") {
            if (event.ctrlKey || event.shiftKey) {
                event.target.blur();
            }
        }
        return;
    }
    if (event.key == "F12") {  // F12
        require('electron').remote.getCurrentWindow().toggleDevTools();
    } else if (event.key in key_commands) {
        key_commands[event.key].command(...key_commands[event.key].args);
        event.preventDefault();
        event.stopPropagation();
    }
});


if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', afterDOMLoaded);
} else {
    afterDOMLoaded();
}

function afterDOMLoaded() {
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

function event_handlers() {
    //extra event handlers, this functions is called form "load_page", when all elements are present

    // star ratings
    document.getElementsByName("image_info_rating").forEach((el) => {
        el.addEventListener("change", function(event) {
            set_rating(event.target.value, only_current=true);
        });
        el.addEventListener("dblclick", function(event) {
            set_rating(0, only_current=true);
        });
    });
    

    // modals
    let els = document.getElementById("modal_help").getElementsByTagName("button");   // the "forEach" method does not work here
    for (let i = 0; i < els.length; i++) {
        els[i].addEventListener('click', show_help);
    }

    // imagezoom
    document.getElementById('imagezoom_container').addEventListener('dblclick', (e) => {
        if (e.ctrlKey || e.shiftKey) {
            toggle_imagezoom("grid");
        }
    });
    
    // menu
    document.getElementById('nav_home').addEventListener('click', (e) => {
        toggle_imagezoom("grid");
        toggle_sidebar(true);
    });
    document.getElementById('nav_help').addEventListener('click', (e) => {
        show_help();
});
}
