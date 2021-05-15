function filter_timeout() {
    // timeout for filtering (we do not always want to start immediately)
    if (document.getElementById('sidebar_filter').classList.contains("is-hidden")) {  // dont do anything if filter-sidebar is not enabled
        return;
    }
    filter_timeout_clear();
    window.timeout_filter = window.setTimeout(filter_items, 100);
}

function filter_timeout_clear() {
    // clears timeout when mouse leaves the element
    if (window.timeout_filter != null) {
        clearTimeout(window.timeout_filter);
    }
}

function filter_showhide(id, show) {
    // show/hide image in the frontend
    if (show) {
        document.getElementById(id).classList.remove('is-hidden');
        document.getElementById("filter_overview_item_" + id).classList.remove('filtered_out');
    } else {
        document.getElementById(id).classList.add('is-hidden');
        document.getElementById("filter_overview_item_" + id).classList.add('filtered_out');
    }
}

function filter_items(ids=[], random_id=-1) {
    // filters items as specified by the input fields in the filter-sidebar
    // if ids is specified (when certain images have been updated, re-filter those images)

    if (random_id == -1) {
        random_id = Date.now();
    }

    if (window.queue_filter_items.length == 0) {  // we can start
        window.queue_filter_items.push(random_id);
    } else if (window.queue_filter_items[0] != random_id) {
        window.queue_filter_items.push(random_id);  // queue up
        setTimeout(function(){
            filter_items(ids, random_id);
        }, 50);
        return;
    }  // else can start as well (and are already queued up)

    open_jobs(1);

    const progressbar = document.getElementById('filter_progress');
    const filter_number = document.getElementById('filter_number');

    progressbar.value=0;
    filter_number.classList.add('is-hidden');
    progressbar.classList.remove('is-hidden');

    const filter_rating = document.querySelector('#sidebar_filter input[name=filter_rating]:checked').value;
    const filter_rating_comparator = document.getElementById('filter_rating_comparator').value;
    const filter_keywords_raw = document.getElementById('filter_keywords').value;
    let filter_keywords = null;
    if (filter_keywords_raw.length > 0) {
        try {
            filter_keywords = create_regexp(filter_keywords_raw);
            document.getElementById('warning_filter_keywords').classList.add("is-invisible");
        } catch(e) {
            document.getElementById('warning_filter_keywords').classList.remove("is-invisible");
        }
    } else {
        document.getElementById('warning_filter_keywords').classList.add("is-invisible");
    }

    const filter_selected = document.getElementById('filter_selected').checked;
    let filter_selected_overview = false;
    if (window.filter_overview_selection_object !== null) {  // this might not exist yet (when images are initially loaded)
        if (window.filter_overview_selection_object.getSelection().length > 0) {
            filter_selected_overview = true;
        }
    }

    const filters_textfield = {};  // will be populated only with the ones that are non-empty
    const textfields = ["filename_original", "comment", "channel_name"];
    textfields.forEach(field => {
        const val_raw = document.getElementById('filter_' + field).value;
        if (val_raw.length > 0) {
            try {
                filters_textfield[field] = create_regexp(val_raw);
                document.getElementById('warning_filter_' + field).classList.add("is-invisible")
            } catch(e) {
                document.getElementById('warning_filter_' + field).classList.remove("is-invisible")
            }
        } else {
            document.getElementById('warning_filter_' + field).classList.add("is-invisible")
        }
    });

    let t0 = performance.now();
    
    if (ids != []) {  // if no ids are specified (this happens when images are updated), we run the filter over all items
        ids = Object.keys(window.items);
    }

    let item = null;
    let filtered_out = false;
    let id = "";
    for (let i=0, imax=ids.length; i<imax; i++) {  // for-loop, so we can do the continue
        id = ids[i];
        item = window.items[id];

        if (i % 20 == 0) {
            progressbar.value = 100 * i / imax;
        }

        if (filter_selected) {  // we do this first because it might limit the number of items a lot
            if (filter_items__selected(id)) {
                continue;
            }
        }
        if (filter_selected_overview) {
            if (filter_items__selected_overview(id)) {
                continue;
            }
        }
        if (filter_items__rating(id, item, filter_rating, filter_rating_comparator)) {
            continue;
        }
        if (filter_keywords != null) {
            if (filter_items__keywords(id, item, filter_keywords)) {
                continue;
            }
        }
        filtered_out = false;
        for (let field in filters_textfield) {
            if (filter_items__textfield(id, item, field, filters_textfield[field])) {
                filtered_out = true;
                break;
            }
        }
        if (filtered_out) {
            continue;
        }
        // item is not filtered out, unhide it
        filter_showhide(id, true);
    }

    let num_result = document.querySelectorAll('#imagegrid .item:not(.is-hidden').length;
    progressbar.classList.add('is-hidden');
    filter_number.innerText = num_result;
    filter_number.classList.remove('is-hidden');

    let t1 = performance.now();
    console.log("filter items:" + (t1 - t0) + " ms.");

    window.queue_filter_items.shift();  // unqueue
    open_jobs(-1);
}

function filter_items__selected(id) {
    // filters by whether the item is selected or not
    let el = document.getElementById(id)
    if (el.classList.contains('active')) {
        return false;
    } else {
        filter_showhide(id, false);
        return true;
    }
}

function filter_items__selected_overview(id) {
    // filters by whether the item is selected or not
    let el = document.getElementById("filter_overview_item_" + id)
    if (el.classList.contains('selected')) {
        return false;
    } else {
        filter_showhide(id, false);
        return true;
    }
}

function filter_items__rating(id, item, filter_rating, filter_rating_comparator) {
    // filters items by rating
    if (filter_rating_comparator == ">=") {
        if (item.rating >= filter_rating) {
            return false;
        } else {
            filter_showhide(id, false);
            return true;
        }
    } else if (filter_rating_comparator == ">") {
        if (item.rating > filter_rating) {
            return false;
        } else {
            filter_showhide(id, false);
            return true;
        }
    } else if (filter_rating_comparator == "=") {
        if (item.rating == filter_rating) {
            return false;
        } else {
            filter_showhide(id, false);
            return true;
        }
    } else if (filter_rating_comparator == "<") {
        if (item.rating < filter_rating) {
            return false;
        } else {
            filter_showhide(id, false);
            return true;
        }
    } else if (filter_rating_comparator == "<=") {
        if (item.rating <= filter_rating) {
            return false;
        } else {
            filter_showhide(id, false);
            return true;
        }
    }
}

function filter_items__keywords(id, item, filter_keywords) {
    // filters items by keywords (filter_keywords shold be a regular expression)

    const keyword_str = "," + item.keywords.join(',') + ",";  // add the delimited in front and end, so that for the search you know that every keyword is enclosed by the delimiter
    if (filter_keywords.test(keyword_str)) {
        return false;
    } else {
        filter_showhide(id, false);
        return true;
    }
}

function filter_items__textfield(id, item, field, filter) {
    // filters item by any text field (filter should be a regular expression)
    if (filter.test(item[field])) {
        return false;
    } else {
        filter_showhide(id, false);
        return true;
    }
}