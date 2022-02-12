
function test_press_key(k, modifiers=[], el=document) {
    // simulates keypress (for testing purposes)
    let props = { key: k };

    if (modifiers.includes("shift")) {
        props["shiftKey"] = true;
    }
    if (modifiers.includes("ctrl")) {
        props["ctrlKey"] = true;
    }
    if (modifiers.includes("alt")) {
        props["altKey"] = true;
    }

    el.dispatchEvent(new KeyboardEvent('keydown', props));
}

function test_click_mouse(selector) {
    // clicks mouse on all elements selected by selector (for testing purposes)
    document.querySelectorAll(selector).forEach(el => {
        el.click();
    });
}

function test_dblclick_mouse(selector) {
    // double-clicks mouse on all elements selected by selector (for testing purposes)
    const event = new MouseEvent('dblclick', {
        'view': window,
        'bubbles': true,
        'cancelable': true
      });
    document.querySelectorAll(selector).forEach(el => {
        // we have to move the mouse as well (dblclick handlers can rely on a hover-state()
        const rect = el.getBoundingClientRect();
        const posx = rect.left + 1;
        const posy = rect.top + 1;
        require("electron").remote.getCurrentWebContents().sendInputEvent({type: 'mouseMove', x: posx, y: posy});
        el.dispatchEvent(event);
    });
}

function test_hover_mouse(selector) {
    // hovers mouse on all elements selected by selector (for testing purposes)
    const event = new MouseEvent('mouseenter', {
        'view': window,
        'bubbles': true,
        'cancelable': true
      });
    document.querySelectorAll(selector).forEach(el => {
        // we have to move the mouse as well (dblclick handlers can rely on a hover-state()
        const rect = el.getBoundingClientRect();
        const posx = rect.left + 1;
        const posy = rect.top + 1;
        require("electron").remote.getCurrentWebContents().sendInputEvent({type: 'mouseMove', x: posx, y: posy});
        el.dispatchEvent(event);
    });
}

function test_sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}


function test_export_to(filename) {
    // extra function here, to avoid the save-dialog

    // export as a presentation; opens dialog to choose filename
    if (get_view() != "grid") {
        return;
    }

    console.log("Export (test) to odp");
    let ids = get_active_element_ids(only_current=false, all_visible_if_none_selected=true);

    if (ids.length > 0) {
        if (filename !== undefined) {
            Blink.msg("grid_item", ["export_odp", ids, filename]);
            open_jobs(1);
            show_message("export (test): " + ids.length + " items to " + filename);
        }
    }
}