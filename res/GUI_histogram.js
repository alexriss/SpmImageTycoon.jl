function Histogram() {
    // histogram object

    this.range = [0.0, 0.0];  // full range of current histogram
    this.unit = "";  // unit for current channel
    this.unit_prefix = "";  // prefix for unit (i.e. m, µ, p, f, ...)
    this.unit_exponent = 0;  // exonent for the unit
    this.drag = false;  // specifies whether we are dragging the colorbar
    this.drag_left = false;  // specifies whether we are dragging the left or right edge of the colorbar
    this.timeout_change_item_range = null;  // timeout reference for change_item_range function

    this.imagezoom_histogram_table_container = document.getElementById('imagezoom_histogram_table_container')
    this.imagezoom_histogram_container = document.getElementById('imagezoom_histogram_container');

    this.canvas = document.getElementById('imagezoom_histogram_canvas');
    this.canvas_width = 1024;
    this.canvas_height = 64;
    this.ctx = this.canvas.getContext("2d");   

    this.histogram = document.getElementById("imagezoom_histogram");
    this.colorbar = document.getElementById("imagezoom_colorbar_container");

    this.imagezoom_range_start = document.getElementById("imagezoom_range_start");
    this.imagezoom_range_end = document.getElementById("imagezoom_range_end");

    this.imagezoom_range_selected_start = document.getElementById("imagezoom_range_selected_start");
    this.imagezoom_range_selected_end = document.getElementById("imagezoom_range_selected_end");

    this.inputs_range_selected = document.querySelectorAll('#imagezoom_table_range input');
    this.texts_range_unit = document.querySelectorAll('#imagezoom_table_range .range_unit_unit');
    this.texts_range_unit_prefix = document.querySelectorAll('#imagezoom_table_range .range_unit_prefix');

    this.unit_prefixes = ["E", "P", "T", "G", "M", "k", "", "m", "u", "n", "p", "f", "a"];
    this.unit_exponents = [18, 15, 12, 9, 6, 3, 0, -3, -6, -9, -12, -15, -18];
   

    // setup event handlers
    this.setup_event_handlers();
}


Histogram.prototype = {
    limit_range_selected(range_selected) {
        // limits the selected range to be between 0 and 1
        if (range_selected[0] < 0) {
            range_selected[0] = 0.0;
        }
        if (range_selected[1] > 1) {
            range_selected[1] = 1.0;
        }

        if (range_selected[0] == range_selected[1]) {  // there should be some difference
            range_selected[0] = range_selected[0] - 1e-6;
            range_selected[1] = range_selected[1] + 1e-6;
            range_selected = this.limit_range_selected(range_selected);  // check again
        }

        return range_selected;
    },

    format_number(number, decimals=2) {
        // formats a number using a unit-prefix and a certain amount of decimals
        return number.toFixed(2);
    },

    convert_absolute_to_absolute_display(range) {
        return [
            this.format_number(range[0] / 10**this.unit_exponent),
            this.format_number(range[1] / 10**this.unit_exponent) 
        ];
    },

    convert_relative_to_absolute_display(range) {
        // converts a relative range to a string that is displayed (absolute numbers, with unit adapted)
        const span = (this.range[1] - this.range[0]);
        return [
            this.format_number((this.range[0] + span * range[0]) / 10**this.unit_exponent),
            this.format_number((this.range[0] + span * range[1]) / 10**this.unit_exponent) 
        ];
    },

    convert_absolute_display_to_relative(range_str) {
        // converts a absolute range from a string (with units adapted) to a relative range
        const span = (this.range[1] - this.range[0]);

        let range_selected_start = parseFloat(range_str[0]) * 10**this.unit_exponent;
        let range_selected_end = parseFloat(range_str[1]) * 10**this.unit_exponent;
        if (isNaN(range_selected_start)) {
            range_selected_start = this.range[0];
        }
        if (isNaN(range_selected_end)) {
            range_selected_end = this.range[1];
        }
        if (range_selected_start > range_selected_end) {  // do not allow low > high
            [range_selected_start, range_selected_end] = [range_selected_end, range_selected_start];
        }

        // convert to relative ranges
        range_selected_start = (range_selected_start - this.range[0]) / span;
        range_selected_end = (range_selected_end - this.range[0]) / span;

        return [range_selected_start, range_selected_end];
    },

    set_prefix() {
        // sets the prefix and exponent
        if (this.range.length != 2) {
            this.unit_prefix = "";
            this.unit_exponent = 0;
            return;
        }

        const max_num = Math.max(Math.abs(this.range[0]), Math.abs(this.range[1]));
        if (max_num == 0) {
            this.unit_prefix = "";
            this.unit_exponent = 0;
            return;
        }
        for (let i=0; i<this.unit_exponents.length;i++) {
            if (max_num > 10**this.unit_exponents[i]) {
                this.unit_exponent = this.unit_exponents[i];
                this.unit_prefix = this.unit_prefixes[i];
                break;
            }
        }

        this.texts_range_unit_prefix.forEach(el => {
            el.innerText = this.unit_prefix;
        });

    },

    draw_bar(upperLeftCornerX, upperLeftCornerY, width, height, color){
        this.ctx.fillStyle=color;
        this.ctx.fillRect(upperLeftCornerX, upperLeftCornerY, width, height);
    },

    plot_histogram(width, counts) {
        // plots a bar chart to the canvas. counts are assumed to be normalized between 0 and 1

        // this seems to reset the canvas without any blinking
        this.canvas.width = this.canvas_width;
        this.canvas.height = this.canvas_height;

        if (counts.length > 1) {  // if there is only one bin (i.e. all values equal), we do not display anything
            for (let i=0, imax=counts.length; i<imax; i++) {
                this.draw_bar(i * width * this.canvas.width,
                    (1 - counts[i]) * this.canvas.height,
                    width * this.canvas.width,
                    counts[i] * this.canvas.height,
                    '#606060'
                );
            }
        }
    },

    set_range_initial(id, range, range_selected, unit) {
        // sets the initial histogram range (and after an update from julia)
        if (this.drag) {
            return;
        }
        console.log("range_initial");
        if (window.queue_edits_range.queue_length(id) > 1) {
            return;  // there are other operations waiting, so we don't update now
        }
        console.log("range_initial2");

        if (range_selected.length != 2) {
            range_selected = [0.0, 1.0];
        }

        this.range = range;
        this.unit = unit;

        this.set_prefix();  // sets the prefix and exponent for the unit

        // full-range values in table
        const range_display = this.convert_absolute_to_absolute_display(range);
        this.imagezoom_range_start.innerText = range_display[0];
        this.imagezoom_range_end.innerText = range_display[1];

        this.texts_range_unit.forEach(el => {
            el.innerText = this.unit;
        });

        // selected-range values in table
        this.set_range_selected(range_selected);

        // colorbar scaling
        const histogram_width = this.histogram.clientWidth;
        this.colorbar.style.left = "" + (histogram_width * range_selected[0]) + "px";
        this.colorbar.style.right = "" + (histogram_width * (1 - range_selected[1])) + "px";
    },

    set_range_selected(range_selected) {
        // updates the selected-range input fields

        const range_selected_display = this.convert_relative_to_absolute_display(range_selected);
        this.imagezoom_range_selected_start.value = range_selected_display[0];
        this.imagezoom_range_selected_end.value = range_selected_display[1];
    },

    set_range_selected_user() {
        // triggers when the selected-range input fields are changed by the user
        let range_selected = this.convert_absolute_display_to_relative([this.imagezoom_range_selected_start.value, this.imagezoom_range_selected_end.value]);
        range_selected = this.limit_range_selected(range_selected);
        this.change_item_range_timeout(window.zoom_last_selected, range_selected, timeout_ms=5);  // call julia
    },

    set_range_user(event, mode="") {
        // sets the histogram range by clicks of the mouse, double-click resets

        if (mode == "reset") {
            this.colorbar.style.left = "0";
            this.colorbar.style.right = "0";
            this.change_item_range_timeout(window.zoom_last_selected, [0, 1]);
            return;
        }

        // const container = document.getElementById("imagezoom_histogram_container");
        const histogram_width = this.histogram.clientWidth;
        const histogram_rect = this.histogram.getBoundingClientRect();
        const colorbar_rect = this.colorbar.getBoundingClientRect();
        let x = event.clientX - histogram_rect.left;

        let update_values = false;

        if (mode == "start") {
            if (Math.abs(event.clientX-colorbar_rect.left) < Math.abs(event.clientX-colorbar_rect.right)) {
                this.drag_left = true;
                this.colorbar.style.left = "" + x + "px";
            } else {
                this.drag_left = false;
                this.colorbar.style.right = "" + (histogram_width - x) + "px";
            }
            this.drag = true;
            update_values = true;
        } else if (this.drag && (mode == "move" || mode == "stop")) {
            if (this.drag_left) {
                if (x < 0) {
                    x = 0;
                } else if (x + histogram_rect.left > colorbar_rect.right - 1) {  // left and right should not cross
                    x = colorbar_rect.right - 1 - histogram_rect.left;
                }
                this.colorbar.style.left = "" + x + "px";
            } else {
                if (x > histogram_width) {
                    x = histogram_width;
                } else if (x + histogram_rect.left < colorbar_rect.left + 1) {  // left and right should not cross
                    x = colorbar_rect.left + 1 - histogram_rect.left;
                }
                this.colorbar.style.right = "" + (histogram_width - x) + "px";
            }

            if (mode == "stop") {
                this.drag = false;
            }
            update_values = true;
        }

        if (update_values) {
            const range_selected_start = (colorbar_rect.left - histogram_rect.left) / histogram_width;
            const range_selected_end = (colorbar_rect.right - histogram_rect.left) / histogram_width;
            const range_selected = this.limit_range_selected([range_selected_start, range_selected_end]);
            this.set_range_selected(range_selected);
            this.change_item_range_timeout(window.zoom_last_selected, range_selected);
        }
    },

    change_item_range_timeout(id, range_selected, timeout_ms=20) {
        // clear old timeout
        if (this.timeout_change_item_range != null && num_open_jobs > 0) {  // only clear if some jobs are running
            clearTimeout(this.timeout_change_item_range);
        }

        this.timeout_change_item_range = window.setTimeout(function() {
            window.queue_edits_range.add(id, "range_selected", () => change_item_range(id, range_selected));  // queue to call Julia
        }, timeout_ms);
    },

    setup_event_handlers() {
        // imagezoom type numbers into input fields
        const that = this;
        this.inputs_range_selected.forEach((el) => {
            el.addEventListener("change", (e) => {
                that.set_range_selected_user();
            });
        });

        // imagezoom select range
        this.imagezoom_histogram_table_container.addEventListener('dblclick', (e) => {
            if (e.target.tagName != "INPUT") {   // double click in inputs is used to select all
                that.set_range_user(e, mode="reset");
            }
        });

        this.imagezoom_histogram_container.addEventListener('mousedown', (e) => {
            that.set_range_user(e, mode="start");
        });

        this.imagezoom_histogram_container.addEventListener('mousemove', (e) => {
            that.set_range_user(e, mode="move");
        });

        window.addEventListener('mouseup', (e) => {  // we need to do it on "window" because the mouse might move outside of the histogram-div
            that.set_range_user(e, mode="stop");
        });
    }
}