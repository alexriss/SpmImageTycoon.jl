function Editing() {
    this.initial_setup_complete = false;
    this.curr_id = "";
    this.timeout_recalculate = null;
    this.updating = false;
    this.editing_entry_list = {};
}


Editing.prototype = {
    initial_setup() {
        if (this.initial_setup_complete) return;

        var that = this;
        document.getElementById("editing_container").querySelectorAll("select, input").forEach(el => {
            el.addEventListener("change", () => {
                that.recalculate_timeout();
            });
        });

        document.getElementById("editing_entry_add").addEventListener("change", () => {
            that.add_entry();
        });

        var el_list = document.getElementById('editing_entry_container');
        this.sortable = Sortable.create(el_list, {
            handle: '.editing_entry_move',
            direction: 'vertical',
            animation: 150,
            easing: "cubic-bezier(0.87, 0, 0.13, 1)",
            draggable: ".editing_entry",
            ghostClass: "editing-entry-ghost",
            onUpdate: function (evt) {
                that.recalculate_timeout();
            }
        });

        this.initial_setup_complete = true;
    },

    setup_form(id, extra_info) {
        if (window.image_info_id != id) return;  // there was some other event already
        this.updating = true;
        this.curr_id = id;
        this.setup_form_main_entry(id, extra_info);
        this.setup_form_editing_entry_list(id);
        this.setup_form_entries(id);
        this.initial_setup();
        this.updating = false;
    },

    setup_form_main_entry(id, extra_info) {
        const item = window.items[id];
        document.getElementById("editing_entry_main_filename").innerText = item.filename_original;

        const el_dir = document.getElementById("editing_entry_main_direction");
        const el_bg = document.getElementById("editing_entry_main_background");
        const el_ch = document.getElementById("editing_entry_main_channel");
        const el_ch2 = document.getElementById("editing_entry_main_channel2");
        this.remove_options(el_dir);
        this.remove_options(el_bg);
        this.remove_options(el_ch);
        this.remove_options(el_ch2);
        const channels = extra_info.Channels.split(", ");
        if (item.type == "SpmGridSpectrum") {
            let spec_channels = channels.filter(ch => !ch.endsWith(" [bwd]"));
            this.add_options(el_dir, window.directions_list["spectrum"], item.scan_direction);
            this.add_options(el_bg, window.background_corrections["spectrum"], item.background_correction);
            this.add_options(el_ch, spec_channels, item.channel_name);
            editing_entry_main_channel2_row.classList.remove("is-hidden");
            this.add_options(el_ch2, spec_channels, item.channel2_name);
        } else if (item.type == "SpmGridImage") {
            let dir = (item.channel_name.endsWith(" bwd")) ? "1" : "0";
            let channel = item.channel_name.replace(" bwd", "");
            this.add_options(el_dir, window.directions_list["image"], dir);
            this.add_options(el_bg, window.background_corrections["image"], item.background_correction);
            this.add_options(el_ch, channels, channel);
            editing_entry_main_channel2_row.classList.add("is-hidden");
        }
    },

    setup_form_editing_entry_list(id) {
        const item = window.items[id];
        const el = document.getElementById("editing_entry_add");
        
        if (item.type == "SpmGridSpectrum") {
            this.editing_entry_list = window.editing_entry_list["spectrum"];
        } else if (item.type == "SpmGridImage") {
            this.editing_entry_list = window.editing_entry_list["image"];
        }

        let opt0;
        if (el.options.length > 0) {
            opt0 = el.options[0];  // first option is a description of the dropdown
        }
        this.remove_options(el);
        el.appendChild(opt0);

        let opts = {}
        for (const [key, value] of Object.entries(this.editing_entry_list)) {
            opts[key] = value.name;
        }
        this.add_options(el, opts, "")
    },

    setup_form_entries(id) {
        // todo;
    },

    remove_options(selectElement) {
        var i, L = selectElement.options.length - 1;
        for(i = L; i >= 0; i--) {
           selectElement.remove(i);
        }
     },

    add_options(selectElement, opts, selected) {
        if (Array.isArray(opts)) {
            var keys = opts;
            var vals = opts;
        } else {
            var keys = Object.keys(opts);
            var vals = Object.values(opts);
        }
        for (let i = 0; i < keys.length; i++) {
            let opt = document.createElement('option');
            opt.value = keys[i];
            opt.innerHTML = vals[i];
            if (selected == keys[i]) {
                opt.selected = true;
            }
            selectElement.appendChild(opt);
        }
    },

    add_entry() {
        const el_add = document.getElementById("editing_entry_add");
        const container = document.getElementById("editing_entry_container");
        const type = el_add.value;
        const props = this.editing_entry_list[type];
        let clone;
        
        if (props.type == "table") {
            const tpl = document.getElementById("editing_entry_template_table");
            clone = tpl.content.cloneNode(true);

            clone.querySelector(".editing_entry_name").innerHTML = props.name;
            id_button = "editing_entry_active_" + this.get_uid();
            clone.querySelector(".editing_entry_buttons input").id = id_button;
            clone.querySelector(".editing_entry_buttons label").htmlFor = id_button;

            const container_row = clone.querySelector(".editing_entry_container_row");
            let tpl_row, clone_row;
            for (const [key, param] of Object.entries(props.params)) {
                if (param.type == "float") {
                    tpl_row = clone.getElementById("editing_entry_template_row_float");
                    clone_row = tpl_row.content.cloneNode(true);
                    clone_row.querySelector(".editing_entry_param_name").innerHTML = param.name;
                    clone_row.querySelector(".editing_entry_param_input").step = param.step;
                    clone_row.querySelector(".editing_entry_param_input").value = param.default;
                    clone_row.querySelector(".editing_entry_param_unit").innerHTML = param.unit;
                } else {
                    console.log("Unknown editing entry param type: " + param.type);
                    continue;
                }
                container_row.appendChild(clone_row);
            }
            clone.querySelectorAll("template").forEach((el) => el.remove());
        } else {
            console.log("Unknown editing entry type: " + props.type);
            return;
        }
        this.add_entry_events(clone);
        container.appendChild(clone);
        el_add.options[0].selected = 'selected';
    },

    add_entry_events(el) {
        // basic events for editing entries
        var that = this;
        el.querySelector(".editing_entry_delete").addEventListener("click", (e) => {
            e.target.closest(".editing_entry").remove();
            that.recalculate_timeout();
        });
        el.querySelector(".editing_entry_active").addEventListener("click", (e) => {
            if (e.target.checked) {
                e.target.closest(".editing_entry").classList.remove("inactive");
            } else {
                e.target.closest(".editing_entry").classList.add("inactive");
            }
            // reclaculate timeout is done for all changes to input, so no need to do it here again
        });

        el.querySelectorAll("input, select").forEach((el) => {
            el.addEventListener("change", (e) => {
                that.recalculate_timeout();
            });
        });
    },

    state_changed(curr_state, item) {
        const res = Object.keys(curr_state).every((key) =>  curr_state[key] == item[key]);
        return !res;
    },

    recalculate_timeout() {
        if (window.image_info_id != this.curr_id || this.updating) return;
        this.recalculate_timeout_clear();
        var that = this;
        window.timeout_recalculate = window.setTimeout(() => that.recalculate(), 30);
    },

    recalculate_timeout_clear() {
        if (window.timeout_recalculate != null) {
            clearTimeout(window.timeout_recalculate);
        }
    },

    recalculate() {
        if (window.image_info_id != this.curr_id) return;

        const curr_id = this.curr_id;
        const item = window.items[curr_id];
        const el_dir = document.getElementById("editing_entry_main_direction");
        const el_bg = document.getElementById("editing_entry_main_background");
        const el_ch = document.getElementById("editing_entry_main_channel");
        const el_ch2 = document.getElementById("editing_entry_main_channel2");

        var curr_state = {};
        curr_state["background_correction"] = el_bg.value;
        if (item.type == "SpmGridSpectrum") {
            curr_state["scan_direction"] = el_dir.value;
            curr_state["channel_name"] = el_ch.value;
            curr_state["channel2_name"] = el_ch2.value;
        } else if (item.type == "SpmGridImage") {
            let dir = el_dir.value;
            let channel_name = el_ch.value;
            if (dir == "1") {
                channel_name += " bwd";
            }
            curr_state["channel_name"] = channel_name;
            if ("channel2_name" in curr_state) {
                delete curr_state["channel2_name"];
            }
            if ("scan_direction" in curr_state) {
                delete curr_state["scan_direction"];
            }
        }

        if (this.state_changed(curr_state, item)) {
            recalculate_item(curr_id, curr_state);
        }
        console.log("recalculate", curr_state, item);
    },

    get_uid() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    }


}


window.editing_object = new Editing();