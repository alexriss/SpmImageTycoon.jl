function filter_overview_rel_to_nm(xy_rel) {
    // converts relative coordinates to physical coordinates
    const scanrange_full = [
        window.topright[0] - window.bottomleft[0],
        window.topright[1] - window.bottomleft[1]
    ];
    const xy_nm = [
        xy_rel[0] * scanrange_full[0] + window.bottomleft[0],
        (1 - xy_rel[1]) * scanrange_full[1] + window.bottomleft[1]  // y in physical units goes from bottom to top
    ];
    return xy_nm;
}

function filter_overview_nm_to_rel(xy_nm, coords=true) {
    // converts physical coordinates to pixel coordinates
    // if coords is false, then a span is assumed (x and y behave similarly)
    var xy_rel = [0.0, 0.0];
    if (coords) {
        xy_rel = [
            (xy_nm[0] - window.bottomleft[0]) / (window.topright[0] - window.bottomleft[0]),
            1 - (xy_nm[1] - window.bottomleft[1]) / (window.topright[1] - window.bottomleft[1])  // y in physical units goes from bottom to top
        ];
    } else {
        xy_rel = [
            xy_nm[0] / (window.topright[0] - window.bottomleft[0]),
            xy_nm[1] / (window.topright[1] - window.bottomleft[1])
        ];
    }
    return xy_rel;
}

function filter_overview_display_coordinates(e) {
    // displays coordinates when mouse moves across the overview

    // get coordinates, similar to GUI_line_profile.js
    const rect = document.getElementById("filter_overview").getBoundingClientRect();
    const xy_rel = [
        (e.clientX - rect.left) / (rect.right - rect.left),
        (e.clientY - rect.top) / (rect.bottom - rect.top)
    ];

    const xy_nm = filter_overview_rel_to_nm(xy_rel);

    document.getElementById("filter_overview_position_x").innerText = xy_nm[0].toFixed(1);
    document.getElementById("filter_overview_position_y").innerText = xy_nm[1].toFixed(1);
}

function filter_overview_clear_selection() {
    // clears selection
    window.filter_overview_selection_object.clearSelection();
    Array.from(document.getElementById('filter_overview').getElementsByClassName('selected')).forEach(el => {
        el.classList.remove('selected');
    });
    filter_overview_display_num_selected();
}

function filter_overview_display_num_selected() {
    // displays number of selected items
    const num_selected = window.filter_overview_selection_object.getSelection().length;
    const filter_overview_info = document.getElementById("filter_overview_info");
    const filter_overview_num_selected_container = document.getElementById("filter_overview_num_selected_container");
    const filter_overview_num_selected = document.getElementById("filter_overview_num_selected");

    filter_overview_num_selected.innerText = num_selected;
    if (num_selected > 0) {
        filter_overview_info.classList.add("is-hidden");
        filter_overview_num_selected_container.classList.remove("is-hidden");
    } else {
        filter_overview_num_selected_container.classList.add("is-hidden");
        filter_overview_info.classList.remove("is-hidden");
    }
}


function filter_overview_setup() {
    // Initialize selectionjs
    window.filter_overview_selection_object = new SelectionArea({
        selectables: ['#filter_overview > .filter_overview_item'],
        boundaries: ['#filter_overview'],
        overlap: 'keep',
        class: "filter_overview_selection_area",
        startThreshold: 1,
        allowTouch: false,
    }).on('beforestart', ({store, event}) => {
        if (event.altKey || window.space_pressed) {
            return false;
        }
    }).on('start', ({store, event}) => {
        if (!event.ctrlKey && !event.metaKey && !event.shiftKey) {  // Remove class if the user isn't pressing the control key or ⌘ key
            window.filter_overview_selecting = true;
            // Unselect all elements
            //for (const el of store.stored) {
            //    el.classList.remove('selected');
            //}
            Array.from(document.getElementById('filter_overview').getElementsByClassName('selected')).forEach(el => {
                el.classList.remove('selected');
            });
    
            // Clear previous selection
            window.filter_overview_selection_object.clearSelection();
        }
    }).on('move', ({store: {changed: {added, removed}}}) => {
        for (const el of added) {
            el.classList.add('selected');
        }
        for (const el of removed) {
            el.classList.remove('selected');
        }
    }).on('stop', () => {
        window.filter_overview_selection_object.keepSelection();
        window.filter_overview_selecting = false;

        filter_overview_display_num_selected();
        filter_items();
    });
}