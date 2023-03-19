const icon_menu = {
    "channel": {
        icon: "media/bx-layer.svg", title: "channel", info_disabled: "select items", for: ["SpmGridImage", "SpmGridSpectrum"],
        commands: {
            prev: () => change_item("channel", "change channel.", -1),
            next: () => change_item("channel", "change channel.", 1),
            list: {
                type: "list",
                entries: {},
                command: (x) => change_items_menu({"channel_name": x}, "set channel.")
            }
        }
    },
    "channel2": {
        icon: "media/bx-layer-x.svg", title: "channel x", info_disabled: "select spectra", for: ["SpmGridSpectrum"],
        commands: {
            prev: () => change_item("channel2", "change x-channel.", -1),
            next: () => change_item("channel2", "change x-channel.", 1),
            list: {
                type: "list",
                entries: {},
                command: (x) => change_items_menu({"channel2_name": x}, "set x-channel.")
            }
        }
    },
    "direction": {
        icon: "media/bx-expand-horizontal.svg", title: "direction", info_disabled: "select items", for: ["SpmGridImage", "SpmGridSpectrum"],
        commands: {
            prev: () => change_item("direction", "change direction.", -1),
            next: () => change_item("direction", "change direction.", 1),
            list: {
                type: "list",
                entries: {
                    0: {
                        val: "&rarr; &nbsp; forward",
                        for: ["SpmGridImage", "SpmGridSpectrum"]
                    },
                    1: {
                        val: "&larr; &nbsp; backward",
                        for: ["SpmGridImage", "SpmGridSpectrum"]
                    },
                    2: {
                        val: "&harr; &nbsp; both",
                        for: ["SpmGridSpectrum"]
                    }
                },  // for images the change is in the name, for specta it is in the field "scan_direction", // todo: needs preparsing by julia
                command: (x) => change_items_menu({"scan_direction": x}, "set direction.")
            }
        }
    },
    "background": {
        icon: "media/bg_correction.svg", title: "background", info_disabled: "select items", for: ["SpmGridImage", "SpmGridSpectrum"],
        commands: {
            prev: () => change_item("background_correction", "change background.", -1),
            next: () => change_item("background_correction", "change background.", 1),
            list: {
                type: "list",
                entries: {},
                command: (x) => change_items_menu({"background_correction": x}, "set background.")
            }
        }
    },
    "colorscheme": { 
        icon: "media/bx-palette.svg", title: "palette", info_disabled: "select images", for: ["SpmGridImage"],
        commands: {
            prev: () => change_item("colorscheme", "change palette.", -1),
            next: () => change_item("colorscheme", "change palette.", 1),
            list: {
                type: "list",
                entries: {},  // has to be initialized when project is loaded
                command: (x) => change_items_menu({"colorscheme": x}, "set palette."),
            }
        }
    },
    "more": {  // revert, virtual copy, delete virtual copy
        icon: "media/bx-dots-horizontal-rounded.svg", title: "more", info_disabled: "select items", for: ["SpmGridImage", "SpmGridSpectrum"],
        commands: {
            list: {
                type: "list",
                entries: {
                    "reset": {
                        val: "reset",
                        for: ["SpmGridImage", "SpmGridSpectrum"],
                        icon: "media/bx-reset.svg",
                        command: (x) => reset_item("reset", "reset.")
                    },
                    "spacer": {},
                    "virtual_copy": {
                        val: "create virtual copy",
                        for: ["SpmGridImage", "SpmGridSpectrum"],
                        icon: "media/virtual_copy_white.svg",
                        command: (x) => virtual_copy("create")
                    },
                    "delete_virtual_copy": {
                        val: "delete virtual copy",
                        for: ["SpmGridVirtualCopy"],
                        icon: "media/x-circle.svg",
                        command: (x) => virtual_copy("delete")
                    }
                },
            }
        }
    },
    "rating": {
        icon: "media/bx-star.svg", title: "rating", info_disabled: "select items", for: ["SpmGridImage", "SpmGridSpectrum"],
        commands: {
            list: {
                type: "list",
                entries: {
                    0: {
                        val: "",
                        icon: "media/rating-0.svg",
                        icon_type: "rating",
                        for: ["SpmGridImage", "SpmGridSpectrum"]
                    },
                    1: {
                        val: "",
                        icon: "media/rating-1.svg",
                        icon_type: "rating",
                        for: ["SpmGridImage", "SpmGridSpectrum"]
                    },
                    2: {
                        val: "",
                        icon: "media/rating-2.svg",
                        icon_type: "rating",
                        for: ["SpmGridImage", "SpmGridSpectrum"]
                    },
                    3: {
                        val: "",
                        icon: "media/rating-3.svg",
                        icon_type: "rating",
                        for: ["SpmGridImage", "SpmGridSpectrum"]
                    },
                    4: {
                        val: "",
                        icon: "media/rating-4.svg",
                        icon_type: "rating",
                        for: ["SpmGridImage", "SpmGridSpectrum"]
                    },
                    5: {
                        val: "",
                        icon: "media/rating-5.svg",
                        icon_type: "rating",
                        for: ["SpmGridImage", "SpmGridSpectrum"]
                    },
                    "spacer": {},
                    "keywords": {
                        val: "keywords",
                        for: ["SpmGridImage", "SpmGridSpectrum"],
                        command: (x) => toggle_keywords_dialog()
                    }
                },  // for images the change is in the name, for specta it is in the field "scan_direction", // todo: needs preparsing by julia
                command: (x) => set_rating(parseInt(x))
            }
        }
    },
    "export": {
        icon: "media/bx-link-external.svg", title: "export", info_disabled: "", for: ["any"],
        commands: {
            list: {
                type: "list",
                entries: {
                    "odp": {
                        val: "export presentation",
                        for: ["any"],
                        command: (x) => export_to("odp")
                    },
                    "spacer": {},
                    "file_loc": {
                        val: "show file location",
                        for: ["SpmGridImage", "SpmGridSpectrum"],
                        command: (x) => open_in_explorer()
                    },
                    "image_loc": {
                        val: "show image location",
                        for: ["SpmGridImage", "SpmGridSpectrum"],
                        command: (x) => open_in_explorer("image")
                    },
                    "file_clipboard": {
                        val: "copy name to clipboard",
                        for: ["SpmGridImage", "SpmGridSpectrum"],
                        command: (x) => copy_to_clipboard()
                    }
                },
            }
        }
    },
};

function setup_menu() {
    setup_menu_main();
    setup_menu_sidebar();
}

function setup_menu_project() {
    icon_menu.colorscheme.commands.list.entries = menu_colorscheme_list();
    update_menu_entries("colorscheme");
}

function setup_menu_selection_callback(channels, channels2) { // called from julia
    icon_menu.channel.commands.list.entries = channels;
    icon_menu.channel2.commands.list.entries = channels2;
    update_menu_entries("channel");
    update_menu_entries("channel2");
}

function setup_menu_selection() {
    get_channels(); // calls julia
}

function menu_colorscheme_list() {
    // creates list of colorschemes to be used in the main menu
    const colorschemes = {}
    Object.keys(filenames_colorbar).forEach((x) => {
        if (!x.endsWith(" inv")) {
            colorschemes[x] = {
                val: x,
                icon: file_url_colorbar_name(x),
                icon_type: "colorscheme",
                for: ["SpmGridImage"],
            }
        };
    });
    colorschemes["spacer"] = {};
    colorschemes["_invert"] = {
        val: "invert",
        icon: "media/cb_invert.png",
        icon_type: "colorscheme",
        for: ["SpmGridImage"],
    }
    return colorschemes;
}

function menu_background_correction_list() {
    // creates list of background corrections to be used in the main menu
    const bg_corrs_image = window.background_corrections["image"];
    const bg_corrs_spectrum = window.background_corrections["spectrum"];
    const bg_corrs = {};
    bg_corrs_image.forEach((x) => {
        bg_corrs[x] = {
            val: x,
            for: ["SpmGridImage"],
        };
    });
    bg_corrs_spectrum.forEach((x) => {
        if (x in bg_corrs) {
            bg_corrs[x].for.push("SpmGridSpectrum");
        } else {
            bg_corrs[x] = {
                val: x,
                for: ["SpmGridSpectrum"],
            };
        }
    });
    return bg_corrs;
}

// channels need to be set up after every selection
function setup_menu_main() {
    // create main icons in navbar
    
    icon_menu.background.commands.list.entries = menu_background_correction_list();

    const container = document.getElementById("menu_main");
    const tpl = document.getElementById("template_icon_menu");

    Object.entries(icon_menu).forEach(([key, value]) => {
        const clone = tpl.content.cloneNode(true);
        clone.firstElementChild.id = "menu_icon_menu_" + key;
        const img = clone.querySelector(".icon img");
        img.src = value.icon;
        const title = clone.querySelector(".icon_menu_title");
        title.innerHTML = value.title;

        const commands = value.commands;
        if ("prev" in commands || "next" in commands) {
            const prev = clone.querySelector(".icon_menu_option_prev");
            prev.addEventListener("click", () => {
                commands.prev();
            });
            const next = clone.querySelector(".icon_menu_option_next");
            next.addEventListener("click", () => {
                commands.next();
            });
        } else {
            clone.querySelector(".icon_menu_options").classList.add("is-hidden");
        }

        if ("for" in value) {
            value.for.forEach((x) => {
                clone.firstElementChild.classList.add("for-" + x);
            });
        }

        if ("info_disabled" in value) {
            const info = clone.querySelector(".icon_menu_info_disabled");
            info.innerHTML = value.info_disabled;
        }

        add_menu_entries(clone, commands);
        if ("command" in value) {
            clone.firstElementChild.addEventListener("click", () => {
                // value.command(); // todo: default command
                // check the -for attribute and only trigger command if it matches selection
            });
        }
        container.appendChild(clone);
    });
}

function add_menu_entries(parent, commands) {
    const tpl_entry = parent.querySelector(".template_icon_menu_dropdown");
    const tpl_spacer = parent.querySelector(".template_icon_menu_spacer");
    const dropdownEl = parent.querySelector(".icon_menu_dropdown");
    if (commands.list.type === "list") {
        Object.entries(commands.list.entries).forEach(([key, value]) => {
            if (key === "spacer") {
                const clone_spacer = tpl_spacer.content.cloneNode(true);
                dropdownEl.appendChild(clone_spacer);
                return;
            }

            const clone_entry = tpl_entry.content.cloneNode(true);
            clone_entry.querySelector(".icon_menu_dropdown_name").innerHTML = value.val;
            if ("icon" in value) {
                clone_entry.querySelector(".icon_menu_dropdown_icon").src = value.icon;
                if ("icon_type" in value) {
                    clone_entry.querySelector(".icon").classList.add(value.icon_type);
                }
            } else {
                clone_entry.querySelector("span.icon").classList.add("is-hidden");
            }

            if ("for" in value) {
                value.for.forEach((x) => {
                    clone_entry.firstElementChild.classList.add("for-" + x);
                });
            }
            const command_func = ("command" in value) ? value.command : commands.list.command;
            clone_entry.firstElementChild.addEventListener("click", () => {
                command_func(key);
                // dropdownEl.classList.add("is-hidden");  // to get rid of the hover effect
                // window.setTimeout(() => {
                //     dropdownEl.classList.remove("is-hidden");
                // }, 50);
            });
            dropdownEl.appendChild(clone_entry);
        });
    }
}

function update_menu_entries(key) {
    const parent = document.getElementById("menu_icon_menu_" + key);
    const commands = icon_menu[key].commands;

    // remove old
    parent.querySelectorAll(".icon_menu_dropdown .navbar-item, .icon_menu_dropdown .navbar-divider").forEach((x) => {
        x.remove();
    });
    add_menu_entries(parent, commands);
}


function setup_menu_sidebar() {
    // create sidebar icons in navbar

    const container = document.getElementById("menu_sidebar");
    const tpl = document.getElementById("template_icon_sidebar");

    Object.entries(icon_sidebar).forEach(([key, value]) => {
        const clone = tpl.content.cloneNode(true);
        clone.firstElementChild.id = "menu_icon_sidebar_" + key;
        const img = clone.querySelector(".icon img");
        img.src = value.icon;
        const title = clone.querySelector(".icon_sidebar_title");
        title.innerHTML = value.title;

        if ("info_disabled" in value) {
            const info = clone.querySelector(".icon_sidebar_info_disabled");
            info.innerHTML = value.info_disabled;
        }
        clone.firstElementChild.addEventListener("click", () => {
            value.command(...value.args);
        });
        container.appendChild(clone);
    });
}

function change_items_menu(state, message) {
    recalculate_items(null, state, "", message);
}