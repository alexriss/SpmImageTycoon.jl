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
                keywords_mode_set_css("set");  // for one element it is always "set"
            } else {
                document.getElementById("modal_keywords_files").innerText = ids.length.toString() + ' files';
            }

            document.getElementById("modal_keywords").classList.add("is-active");
            window.keywords_input.DOM.input.focus();
        }
    }
}

function keywords_mode_set_css(keywords_mode) {
    // sets css classes according to the mode (set, add, remove)
    // color mode button and save button
    for (let i=0; i<window.keywords_modes_display_css_classes.length; i++) {
        if (keywords_mode == window.keywords_modes[i]) {
            document.getElementById("modal_keywords_mode").classList.add(window.keywords_modes_display_css_classes[i]);
            document.getElementById("modal_keywords_button_save").classList.add(window.keywords_modes_display_css_classes[i]);
        } else {
            document.getElementById("modal_keywords_mode").classList.remove(window.keywords_modes_display_css_classes[i]);
            document.getElementById("modal_keywords_button_save").classList.remove(window.keywords_modes_display_css_classes[i]);
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
    keywords_mode_set_css(window.keywords_mode);
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
