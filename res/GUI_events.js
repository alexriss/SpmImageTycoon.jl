// keyboard events etc

let key_commands = {
    c: { command: change_item, args: ["channel", "change channel."] },
    d: { command: change_item, args: ["direction", "change direction."] },
    b: { command: change_item, args: ["background_correction", "change background."] },
    p: { command: change_item, args: ["colorscheme", "change colorscheme."] },
    i: { command: change_item, args: ["inverted", "invert colorscheme."] },
    C: { command: change_item, args: ["channel", "change channel.", -1] },
    D: { command: change_item, args: ["direction", "change direction.", -1] },
    B: { command: change_item, args: ["background_correction", "change background.", -1] },
    P: { command: change_item, args: ["colorscheme", "change colorscheme.", -1] },
    I: { command: change_item, args: ["inverted", "invert colorscheme."] },
    "&": { command: virtual_copy, args: ["create"] },
    a: { command: toggle_all_active, args: [] },
    A: { command: toggle_all_active, args: [true] },
    n: { command: clear_all_active, args: []},
    m: { command: toggle_sidebar, args: ["info"] },
    f: { command: toggle_sidebar, args: ["filter"] },
    t: { command: toggle_sidebar_imagezoomtools, args: [] },
    z: { command: toggle_imagezoom, args: [] },
    0: { command: set_rating, args: [0] },
    1: { command: set_rating, args: [1] },
    2: { command: set_rating, args: [2] },
    3: { command: set_rating, args: [3] },
    4: { command: set_rating, args: [4] },
    5: { command: set_rating, args: [5] },
    k: { command: toggle_keywords_dialog, args: [] },
    h: { command: toggle_help, args: [] },
    "?": { command: toggle_help, args: [] },
    "/": { command: toggle_help, args: [] },
    F1: { command: toggle_help, args: [] },
    ArrowRight: { command: next_item, args: [1] },
    ArrowLeft: { command: next_item, args: [-1] },
    Escape: { command: escape_handler, args: [] },
}

// with shift-modifier (some of the normal ones also work with the shift key)
let shift_key_commands = {
    E: { command: open_in_explorer, args: [] },
    Delete: { command: virtual_copy, args: ["delete"] },
}

let alt_key_commands = {
    e: { command: open_in_explorer, args: ["image"] },
}

// with ctrl-modifier
let ctrl_key_commands = {
    a: { command: toggle_all_active, args: [true] },
    s: { command: save_all, args: [] },
    e: { command: export_to, args: ["odp"] },
    f: { command: image_info_search_parameter, args: [] },
    w: { command: toggle_start_project, args: ["start", true] },
    q: { command: toggle_start_project, args: ["re-project"] },
    F12: { command: toggle_dev_tools, args: [] },
    F5: { command: re_parse_images, args: [] },
}

// for debugging, F5 for reload, F12 for dev tools
document.addEventListener("keydown", function (event) {
    let view = get_view();
    if (view == "error") {
        if (["Escape", "Return"].includes(event.key)) {
            toggle_error();
        }
        return;  // no other special keys allowed
    } else if (view == "help") {    // only certain buttons allowed
        if (["Escape", "?", "/", "h", "F1"].includes(event.key)) {
            toggle_help();
        }
        return;  // no other special keys allowed
    } else if (view == "about") {    // only certain buttons allowed
        if (["Escape"].includes(event.key)) {
            toggle_about();
        }
        return;  // no other special keys allowed
    } else if (view == "keywords") {
        if (event.key == "Escape") {
            toggle_keywords_dialog();
        } else if (event.ctrlKey || event.shiftKey) {  // save
            if (event.key == "s") {
                set_keywords();
                toggle_keywords_dialog();
            } else if (event.key == "c") {
                keywords_copy_to_clipboard(event);
                event.preventDefault();
            } else if (event.key == "m") {
                toggle_keywords_mode();
                event.preventDefault();
            }
        }
    } else if (event.target.nodeName == "INPUT" || event.target.nodeName == "TEXTAREA" || event.target.isContentEditable) {
        if (event.key == "Escape") {
            event.target.blur();
        }
    } else if (event.ctrlKey) {
        if (event.key in ctrl_key_commands) {
            ctrl_key_commands[event.key].command(...ctrl_key_commands[event.key].args);
        }
    } else if (event.shiftKey && event.key in shift_key_commands) {  // this will not block the non-modifier commands (some of those can only be typed with the shift key)
        shift_key_commands[event.key].command(...shift_key_commands[event.key].args);
    } else if (event.altKey && event.key in alt_key_commands) {  // this will not block the non-modifier commands (some of those can only be typed with the shift key)
        alt_key_commands[event.key].command(...alt_key_commands[event.key].args);
    } else if (event.key in key_commands) {
        key_commands[event.key].command(...key_commands[event.key].args);
        event.preventDefault();
        event.stopPropagation();
    } else if (event.key == " ") {
        window.space_pressed = true;  // we track this for zooming
    }
});

document.addEventListener("keyup", function (event) {
    if (event.key == " ") {
        window.space_pressed = false;
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
            set_rating(parseInt(event.target.value), only_current=true);
        });
        el.addEventListener("dblclick", function(event) {
            set_rating(0, only_current=true);
        });
    });
    
    // modals
    let els;
    els = document.getElementById("modal_help").getElementsByTagName("button");   // the "forEach" method does not work here
    for (let i = 0; i < els.length; i++) {
        els[i].addEventListener('click', toggle_help);
    }

    els = document.getElementById("modal_about").getElementsByTagName("button");   // the "forEach" method does not work here
    for (let i = 0; i < els.length; i++) {
        els[i].addEventListener('click', toggle_about);
    }

    els = document.getElementById("modal_error").getElementsByTagName("button");   // the "forEach" method does not work here
    for (let i = 0; i < els.length; i++) {
        els[i].addEventListener('click', toggle_error);
    }

    els = document.getElementById("modal_keywords").getElementsByTagName("button");   // the "forEach" method does not work here
    for (let i = 0; i < els.length; i++) {
        if (els[i].classList.contains("is-success")) {
            els[i].addEventListener('click', (e) => {
                set_keywords();
                toggle_keywords_dialog();
            });
        } else if (els[i].id == "modal_keywords_mode") {
            els[i].addEventListener('click', (e) => { toggle_keywords_mode(); });  // we have to make sure that the event object is not passed as an argument
        } else {
            els[i].addEventListener('click', toggle_keywords_dialog);
        }
    }
    // make keywords modal draggable
    dragElement(document.getElementById("modal_keywords"), document.getElementById("modal_keywords_header"));

    // imagezoom
    document.getElementById('imagezoom_container').addEventListener('dblclick', (e) => {
        if (e.ctrlKey) {
            toggle_imagezoom("grid");
        }
    });

    // we need to adjust image css to fit it to the div (with css "object-fit: contain" we can't retrieve the computed image-position and width.)
    const resizeObserver = new ResizeObserver(entries => {
        imagezoom_size_adjust();
    });
    resizeObserver.observe(document.getElementById('imagezoom_content'));

    // filter sidebar
    document.querySelectorAll('#sidebar_filter_table input,select').forEach((el) => {
        el.addEventListener("input", filter_timeout);
    });

    Array.from(document.getElementById('sidebar_filter_table').getElementsByClassName('delete')).forEach(el => {
        if (el.id == "button_delete_filter_rating") {
            el.addEventListener('click', function(e) {
                document.getElementById('filter_rating_0').checked = true;
                document.getElementById('filter_rating_comparator').value= ">=";
                if (e.screenX) {  // "reset all" will click all buttons, then we do not want to trigger the filter here
                    filter_items();
                }
            })
        } else if (el.id == "button_delete_filter_selected") {
            el.addEventListener('click', function(e) {
                document.getElementById('filter_selected').checked = false;
                if (e.screenX) {  // "reset all" will click all buttons, then we do not want to trigger the filter here
                    filter_items();
                }
            });
        } else {
            let id_field = el.id.replace("button_delete_", "");
            el.addEventListener('click', function(e) {
                document.getElementById(id_field).value = '';
                if (e.screenX) {  // "reset all" will click all buttons, then we do not want to trigger the filter here
                    filter_items();
                }
            });
        }
    });

    document.getElementById('button_delete_all_filters').addEventListener('click', function() {
        Array.from(document.getElementById('sidebar_filter_table').getElementsByClassName('delete')).forEach(el => {
            el.click();
        });
        filter_items();
    });

    // sidebar accordion
    els = document.getElementsByClassName("sidebar_accordion");
    for (let i=0; i<els.length; i++) {
        els[i].addEventListener("click", function() {
            this.classList.toggle("sidebar_accordion_active");
            let panel = this.nextElementSibling;
            panel.classList.toggle("is-hidden");
            if (window.line_profile_object !== null) {
                window.line_profile_object.setup();  // will set up or remove event handlers
            }
        });
    }

    // menu
    document.getElementById('nav_home').addEventListener('click', (e) => {
        if (get_view() == "start") {
            return;
        }
        standard_view();
    });
    document.getElementById('nav_help').addEventListener('click', (e) => {
        toggle_help();
    });
    document.getElementById('nav_about').addEventListener('click', (e) => {
        toggle_about();
    });

    // load directory button
    document.getElementById('page_start_open_directory_button').addEventListener('click', (e) => {
        select_directory();
    });

    // on close
    require('electron').remote.getCurrentWindow().on('close', (e) => {
        save_all(true);
        return false;
    });

    // auto-save every n minutes
    if (window.auto_save_minutes > 0) {
        setInterval(save_all, 1000 * 60 * window.auto_save_minutes);
    }

    // open links externally by default
    els = document.querySelectorAll("a.external");
    for (let i = 0; i < els.length; i++) {
        els[i].addEventListener('click', (e) => {
            e.preventDefault();
            require("electron").shell.openExternal(e.target.href);
        });
    }
}
