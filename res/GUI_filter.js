function FilterItems() {
    this.running = false;
    this.progressbar = document.getElementById('filter_progress');
    this.filter_number = document.getElementById('filter_number');
    this.timeout_filter = null;  // timeout refrence for filter function
    this.queue_filter_items = [];  // queue for filter_items functions - only one instance should run at a time
    this.warning = {
        "keywords": document.getElementById('warning_filter_keywords'),
        "scansize": document.getElementById('warning_filter_scansize'),
        "filename_original": document.getElementById('warning_filter_filename_original'),
        "comment": document.getElementById('warning_filter_comment'),
        "channel_name": document.getElementById('warning_filter_channel_name'),
    }

    this.show = true;
    this.show_class = "is-hidden";
}


FilterItems.prototype = {
    filter_showhide(id, show) {
        // show/hide image in the frontend
        if (show) {
            document.getElementById(id).classList.remove(this.show_class);
            document.getElementById("filter_overview_item_" + id).classList.remove('filtered_out');
        } else {
            document.getElementById(id).classList.add(this.show_class);
            document.getElementById("filter_overview_item_" + id).classList.add('filtered_out');
        }
    },

    filter_items(ids=[], random_id=-1) {
        // filters items as specified by the input fields in the filter-sidebar
        // if ids is specified (when certain images have been updated, re-filter those images)

        const other_running = this.running;
        this.running = true;
        if (random_id == -1) {  // new item in the queue
            random_id = Math.random().toString(36).substring(2) + Date.now();
            this.queue_filter_items.push(random_id);
        } else {
            if (this.queue_filter_items.length > 0 && this.queue_filter_items[this.queue_filter_items.length-1] != random_id) {
                return;  // there are already some new filters queued up, we can discard this one
            }
        }
        if (other_running) {
            setTimeout(function () {
                this.filter_items(ids, random_id);
            }, 10);
            return;
        } 

        open_jobs(1);

        this.progressbar.value = 0;
        this.filter_number.classList.add('is-hidden');
        this.progressbar.classList.remove('is-hidden');

        this.filter_mode();

        const filter_rating = document.querySelector('#sidebar_filter input[name=filter_rating]:checked').value;
        const filter_rating_comparator = document.getElementById('filter_rating_comparator').value;
        const filter_scansize_comparator = document.getElementById('filter_scansize_comparator').value;
        const filter_type = document.getElementById('filter_type').value;
        const filter_keywords_raw = document.getElementById('filter_keywords').value;
        let filter_keywords = null;
        if (filter_keywords_raw.length > 0) {
            try {
                filter_keywords = create_regexp(filter_keywords_raw);
                this.warning.keywords.classList.add("is-invisible");
            } catch (e) {
                this.warning.keywords.classList.remove("is-invisible");
            }
        } else {
            this.warning.keywords.classList.add("is-invisible");
        }

        let filter_scansize = "";
        if (document.getElementById("filter_scansize").validity.valid) {
            filter_scansize = document.getElementById("filter_scansize").value;
            this.warning.scansize.classList.add("is-invisible");
        } else {
            this.warning.scansize.classList.remove("is-invisible");
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
                    this.warning[field].classList.add("is-invisible")
                } catch (e) {
                    this.warning[field].classList.remove("is-invisible")
                }
            } else {
                this.warning[field].classList.add("is-invisible")
            }
        });

        let t0 = performance.now();

        if (ids != []) {  // if no ids are specified (this happens when images are updated), we run the filter over all items
            ids = Object.keys(window.items);
        }

        let item = null;
        let filtered_out = false;
        let id = "";
        for (let i = 0; i < ids.length; i++) {  // for-loop, so we can do `continue`
            id = ids[i];
            item = window.items[id];

            if (i % 20 == 0) {
                this.progressbar.value = 100 * i / ids.length;
            }

            if (filter_selected) {  // we do this first because it might limit the number of items a lot
                if (this.filter_items__selected(id)) {
                    continue;
                }
            }
            if (filter_selected_overview) {
                if (this.filter_items__selected_overview(id)) {
                    continue;
                }
            }
            if (this.filter_items__rating(id, item, filter_rating, filter_rating_comparator)) {
                continue;
            }
            if (this.filter_items__type(id, item, filter_type)) {
                continue;
            }
            if (filter_scansize !== "") {
                if (this.filter_items__scansize(id, item, filter_scansize, filter_scansize_comparator)) {
                    continue;
                }
            }
            if (filter_keywords != null) {
                if (this.filter_items__keywords(id, item, filter_keywords)) {
                    continue;
                }
            }
            filtered_out = false;
            for (let field in filters_textfield) {
                if (this.filter_items__textfield(id, item, field, filters_textfield[field])) {
                    filtered_out = true;
                    break;
                }
            }
            if (filtered_out) {
                continue;
            }
            // item is not filtered out, unhide it
            this.filter_showhide(id, this.show);
        }

        let num_result = document.querySelectorAll(this.filter_selector).length;
        this.progressbar.classList.add('is-hidden');
        this.filter_number.innerText = num_result;
        this.filter_number.classList.remove('is-hidden');

        let t1 = performance.now();
        console.log("filter items:" + (t1 - t0) + " ms.");

        while (this.queue_filter_items[0] != random_id && this.queue_filter_items.length > 0) {
            this.queue_filter_items.shift();  // unqueue
        }
        this.running = false;
        open_jobs(-1);
    },

    filter_mode() {
        // sets filter mode and selector, removes previous css classes
        const filter_mode = document.getElementById('filter_mode').value;
        this.show = (filter_mode == "in") ? true : false;
        this.show_class = (filter_mode == "mark") ? "is-marked" : "is-hidden";
        if (filter_mode == "mark") {
            document.querySelectorAll('#imagegrid .item.is-hidden').forEach(item => {
                item.classList.remove('is-hidden');
            });
        } else {
            document.querySelectorAll('#imagegrid .item.is-marked').forEach(item => {
                item.classList.remove('is-marked');
            });
        }
        if (this.show) {
            this.filter_selector = '#imagegrid .item:not(' + this.show_class + ')';
        } else {
            this.filter_selector = '#imagegrid .item.' + this.show_class;
        }
    },

    filter_items__selected(id) {
        // filters by whether the item is selected or not
        let el = document.getElementById(id)
        if (el.classList.contains('active')) {
            return false;
        } else {
            this.filter_showhide(id, !this.show);
            return true;
        }
    },

    filter_items__selected_overview(id) {
        // filters by whether the item is selected or not
        let el = document.getElementById("filter_overview_item_" + id)
        if (el.classList.contains('selected')) {
            return false;
        } else {
            this.filter_showhide(id, !this.show);
            return true;
        }
    },

    filter_comparator(a, b, comparator) {
        // compares two numbers using the comparator
        if (comparator == "=") {
            return a == b;
        } else if (comparator == ">") {
            return a > b;
        } else if (comparator == "<") {
            return a < b;
        } else if (comparator == ">=") {
            return a >= b;
        } else if (comparator == "<=") {
            return a <= b;
        } else {
            return false;
        }
    },

    filter_items__rating(id, item, filter_rating, filter_rating_comparator) {
        // filters items by rating
        if (this.filter_comparator(item.rating, filter_rating, filter_rating_comparator)) {
            return false;
        } else {
            this.filter_showhide(id, !this.show);
            return true;
        }
    },

    filter_items__scansize(id, item, filter_scansize, filter_scansize_comparator) {
        const scansize = (item.scansize.length == 2) ? item.scansize[0] * item.scansize[1] : 0.0;
        if (this.filter_comparator(scansize, filter_scansize, filter_scansize_comparator)) {
            return false;
        } else {
            this.filter_showhide(id, !this.show);
            return true;
        }
    },

    filter_items__type(id, item, filter_type) {
        // filters items by type ("any", SpmGridImage", "SpmGridSpectrum")
        if (filter_type == "any") {
            return false;
        } else if (item.type == filter_type) {
            return false;
        } else {
            this.filter_showhide(id, !this.show);
            return true;
        }
    },

    filter_items__keywords(id, item, filter_keywords) {
        // filters items by keywords (filter_keywords shold be a regular expression)

        const keyword_str = "," + item.keywords.join(',') + ",";  // add the delimited in front and end, so that for the search you know that every keyword is enclosed by the delimiter
        if (filter_keywords.test(keyword_str)) {
            return false;
        } else {
            this.filter_showhide(id, !this.show);
            return true;
        }
    },

    filter_items__textfield(id, item, field, filter) {
        // filters item by any text field (filter should be a regular expression)
        if (filter.test(item[field])) {
            return false;
        } else {
            this.filter_showhide(id, !this.show);
            return true;
        }
    }
}


