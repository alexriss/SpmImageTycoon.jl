function Editing() {
    this.initial_setup_complete = false;
    this.curr_id = "";
    this.updating = false;
    this.editing_entry_list = {};  // possible entries for images or spectra
    this.info = {};  // extra info sent in pars
}


Editing.prototype = {
    initial_setup() {
        if (this.initial_setup_complete) return;

        const that = this;
        document.getElementById("editing_entry_main").querySelectorAll("select, input").forEach(el => {
            el.addEventListener("change", () => {
                that.recalculate();
            });
        });

        document.getElementById("editing_entry_add").addEventListener("change", () => {
            that.add_entry_from_form();
            that.recalculate();
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
                that.recalculate();
            }
        });

        if (window.queue_edits_range == null) window.queue_edits_range = new Queue();

        this.initial_setup_complete = true;
    },

    set_img_src(el, id, n, repeat=0) {
        el.src = file_url_edit(id, "FT_" + n);
        if (repeat > 1) return;  // we tried two times, the image should be there

        // if there are no other edits in the queue, we reload the image one more time,
        // because sometimes generation takes longer (and it anyways doesn't hurt to reload)
        if (!window.queue_edits_range.type_in_queue(id, "edit")) {
            const that = this;
            const waitms = 60 * (repeat + 1);
            window.setTimeout(() => {
                that.set_img_src(el, id, n, repeat+1);  // sometimes the image generation is slow, so we call it again
            }, waitms);
        }
    },

    setup_form(id, extra_info) {
        if (window.image_info_id != id) return;  // there was some other event already
        this.updating = true;

        let update_entries = false;
        if (id === this.curr_id) {
            update_entries = true;  // we are updating the same image, so we keep the entries
        } else {
            window.draw_rect_objects = {};  // lets get rid of the old objects, so that they don't interfere
        }
        this.curr_id = id;
        this.setup_form_main_entry(id, extra_info);
        this.setup_form_editing_entry_list(id);
        this.setup_form_entries(id, update=update_entries);
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

    setup_form_entries(id, update=false) {
        if (update && window.queue_edits_range.type_in_queue(id, "edit")) {
            return;  // there are other operations waiting, so we don't update now
        }
        const item = window.items[id];
        const entries = item.edits.map(edit => JSON.parse(edit));
        const ids_new = entries.map(e => e.id);
        // check that all entries are the same - then we can just update them, instead delete and recreate
        if (update) {
            const ids_curr = this.get_entry_list().map(e => e.id);
            if (ids_curr.join(",") != ids_new.join(","))  update = false;
        }

        const container = document.getElementById("editing_entry_container");
        if (update) {
            const container = document.getElementById("editing_entry_container");
            let entries_form = [];
            container.querySelectorAll(".editing_entry").forEach((el) => {
                entries_form.push(el);
            });
            for (let i = 0; i < entries.length; i++) {
                this.add_entry_from_item(entries[i], entries_form[i]);
            }    
        } else {
            container.querySelectorAll(":scope > .editing_entry").forEach(el => {
                el.remove();
            });
            for (let i = 0; i < entries.length; i++) {
                this.add_entry_from_item(entries[i]);
            }    
        }
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

    add_entry_from_form() {
        const el_add = document.getElementById("editing_entry_add");
        const key = el_add.value;
        this.add_entry(key);
        el_add.options[0].selected = 'selected';
    },

    add_entry_from_item(props_item, el_update=null) {
        const key = props_item.id;
        this.add_entry(key, props_item, el_update);
    },

    add_entry(key,  props_item={}, el_update=null) {
        const container = document.getElementById("editing_entry_container");
        if (!(key in this.editing_entry_list)) {
            console.log("Unknown editing entry: " + key);
            return;
        }
        const props = this.editing_entry_list[key];
        let clone;

        if (props.type == "table") {
            if (el_update == null) {
                clone = this.add_entry_table(key, props, props_item);
                this.add_entry_events(clone);
                container.appendChild(clone);
            } else {
                clone = this.update_entry_table(props, props_item, el_update);
            }
        } else {
            console.log("Unknown editing entry type: " + props.type);
            return;
        }
    },

    update_entry_table(props, props_item, el_entry) {
        const that = this;
        const el_active = el_entry.querySelector(".editing_entry_buttons input");
        if ("off" in props_item) {
            if (props_item.off) {
                el_active.checked = false;
                el_entry.classList.add("inactive");
            }
        }
        const divCollapse = el_entry.querySelector(".editing_entry_collapse");
        if ("exp" in props_item) {
            if (props_item.exp) {
                divCollapse.classList.remove("is-hidden");
            } else {
                divCollapse.classList.add("is-hidden");
            }
        }
        const n = props_item["n"];

        Object.entries(props_item.pars).forEach(([key, par_item]) => {
            const par = props.pars[key];
            if (par.type === "info") {
                that.info[key] = par_item;
                return;
            }
            const el_par = el_entry.querySelector('[data-id="' + key + '"]');
            if (el_par) {
                if (par.type === "float") {
                    el_par.value = par_item;
                    that.check_input_validity(el_par);
                } else if (par.type === "select") {
                    el_par.value = par_item;
                } else if (par.type === "FT_select") {
                    that.set_img_src(el_par, that.curr_id, n);
                    if (window.draw_rect_objects[n]) {
                        window.draw_rect_objects[n].loadPoints(par_item);
                        window.draw_rect_objects[n].setInfo(that.info);
                    } else {
                        console.log("No draw_rect_objects for n: " + n);
                    }
                }
            } else {
                console.log("Unknown editing entry parameter: " + key);
            }
        });
    },

    add_entry_table(key, props, props_item={}) {
        const that = this;
        const item = window.items[this.curr_id];
        const tpl = document.getElementById("editing_entry_template_table");
        clone = tpl.content.cloneNode(true);
        const el_entry = clone.querySelector(".editing_entry");
        el_entry.dataset.id = key;
        const n = this.get_entry_num() + 1;
        el_entry.dataset.n = n;

        clone.querySelector(".editing_entry_name").innerHTML = props.name;
        const id_button = "editing_entry_active_" + this.get_uid();
        const el_active = clone.querySelector(".editing_entry_buttons input");
        el_active.id = id_button;
        clone.querySelector(".editing_entry_buttons label").htmlFor = id_button;
        if ("off" in props_item) {
            if (props_item.off) {
                el_active.checked = false;
                el_entry.classList.add("inactive");
            }
        }
        const divCollapse = el_entry.querySelector(".editing_entry_collapse");
        if ("exp" in props_item) {
            if (props_item.exp) {
                divCollapse.classList.remove("is-hidden");
            } else {
                divCollapse.classList.add("is-hidden");
            }
        }

        const container_row = clone.querySelector(".editing_entry_container_row");
        let tpl_row, clone_row, clone_row_more, img_ft, el_lambdaX, el_lambdaY, el_lambdaA, el_lambdaAngle;
        let i_row = 0;
        for (const [key, par] of Object.entries(props.pars)) {
            i_row++;  // we increase here, so that the first row is 1 as in julia
            if (par.type === "float") {
                tpl_row = clone.getElementById("editing_entry_template_row_float");
                clone_row = tpl_row.content.cloneNode(true);
                clone_row.querySelector(".editing_entry_par_name").innerHTML = par.name;
                clone_row.querySelector(".editing_entry_par_unit").innerHTML = par.unit;
                const el_input = clone_row.querySelector(".editing_entry_par_input");
                el_input.dataset.id = key;
                if ("pars" in props_item && key in props_item.pars) {
                    el_input.value = this.format_number(props_item.pars[key], par);
                } else {
                    el_input.value = this.format_number(par.default, par);
                }
                el_input.dataset.default = par.default;
                if ("step" in par) el_input.setAttribute("step", par.step);
                if ("dragstep" in par) el_input.dataset.dragstep = par.dragstep;
                // if ("max" in par) el_input.setAttribute("max", par.max);
                // if ("min" in par) el_input.setAttribute("min", par.min);
                // we set it in the data-attributes, because the min-attribute messes up the step
                if ("min" in par) el_input.dataset.min = par.min;
                if ("max" in par) el_input.dataset.max = par.max;
                if ("digits" in par) el_input.dataset.digits = par.digits;
                input_number_dragable(el_input);
            } else if (par.type === "select") {
                tpl_row = clone.getElementById("editing_entry_template_row_select");
                clone_row = tpl_row.content.cloneNode(true);
                clone_row.querySelector(".editing_entry_par_name").innerHTML = par.name;
                const el_select = clone_row.querySelector(".editing_entry_par_select");
                el_select.dataset.id = key;
                for (const [key, val] of Object.entries(par.options)) {
                    const el_option = document.createElement("option");
                    el_option.value = key;
                    el_option.innerHTML = val;
                    el_select.appendChild(el_option);
                }
                if ("pars" in props_item && key in props_item.pars) {
                    el_select.value = props_item.pars[key];
                } else {
                    el_select.value = par.default;
                }
                el_select.dataset.default = par.default;
            } else if (par.type === "FT_select") {
                tpl_row = clone.getElementById("editing_entry_template_row_FT_select");
                clone_row = tpl_row.content.cloneNode(true);
                img_ft = clone_row.querySelector(".editing_entry_FT_image")
                el_lambdaX = clone_row.querySelector(".editing_entry_FT_lambda_x");
                el_lambdaY = clone_row.querySelector(".editing_entry_FT_lambda_y");
                el_lambdaA = clone_row.querySelector(".editing_entry_FT_lambda_a");
                el_lambdaAngle = clone_row.querySelector(".editing_entry_FT_lambda_angle");
                img_ft.dataset.id = key;
                img_ft.addEventListener("load", () => {
                    window.draw_rect_objects[n].setup(
                        callback=() => that.recalculate(), scansize=item.scansize, info=that.info, nObj=n,
                    );
                    if ("pars" in props_item && key in props_item.pars) {
                        window.draw_rect_objects[n].loadPoints(props_item.pars[key]);
                    }
                }, {once: true});
                window.draw_rect_objects[n] = new DrawRects(
                    clone_row.querySelector(".editing_entry_FT_canvas"), img_ft, clone_row.querySelector(".editing_entry_FT_container"),
                    clone_row.querySelector(".editing_entry_FT_container_events"), el_lambdaX, el_lambdaY, el_lambdaA, el_lambdaAngle
                );
                this.set_img_src(img_ft, this.curr_id, n);
                clone_row.querySelector(".editing_entry_FT_clear_all").addEventListener("click", () => {
                    window.draw_rect_objects[n].clearAll();
                });
                // bit hacky, but we want to change the colors depending on the filter type
                const elFilterType = clone.querySelector('[data-id="f"]');
                if (elFilterType) {
                    window.draw_rect_objects[n].setColors(elFilterType.value);
                    elFilterType.addEventListener("change", () => {
                        window.draw_rect_objects[n].setColors(elFilterType.value);
                    });
                }
            } else if (par.type === "info") {
                if ("pars" in props_item && key in props_item.pars) {
                    this.info[key] = props_item.pars[key];
                } else {
                    this.info[key] = par.default;
                }
                continue;
            } else {
                console.log("Unknown editing entry par type: " + par.type);
                continue;
            }

            // make expandable and collapsible par rows
            if ("more" in props && props.more.length === 2) {
                if (i_row == props.more[0]) {
                    const tpl_row_more = clone.getElementById("editing_entry_template_row_more");
                    clone_row_more = tpl_row_more.content.cloneNode(true);   
                    container_row.appendChild(clone_row_more); 
                }
                if (i_row >= props.more[0] && i_row <= props.more[1]) {
                    clone_row.querySelector("tr").dataset.more = "1";
                    clone_row.querySelector("tr").classList.add("is-hidden");
                }
            }
            
            container_row.appendChild(clone_row);
        }
        clone.querySelectorAll("template").forEach((el) => el.remove());
        return clone;
    },

    add_entry_events(el) {
        // basic events for editing entries
        var that = this;
        el.querySelector(".editing_entry_delete").addEventListener("click", (e) => {
            e.target.closest(".editing_entry").remove();
            that.recalculate();
        });
        el.querySelector(".editing_entry_active").addEventListener("click", (e) => {
            if (e.target.checked) {
                e.target.closest(".editing_entry").classList.remove("inactive");
            } else {
                e.target.closest(".editing_entry").classList.add("inactive");
            }
            // recalculate is done for all changes to input, so no need to do it here again
        });
        el.querySelectorAll("input, select").forEach((el) => {
            el.addEventListener("change", (e) => {
                that.check_input_validity(el);
                that.recalculate();
            });
        });

        // double click name to reset to default
        el.querySelectorAll(".editing_entry_par_name").forEach((el) => {
            el.addEventListener("dblclick", (e) => {
                const el_input_select = e.target.closest("tr").querySelector(".editing_entry_par_select, .editing_entry_par_input");
                if (el_input_select !== null && "default" in el_input_select.dataset) {
                    el_input_select.value = el_input_select.dataset.default;
                    that.check_input_validity(el_input_select);
                    that.recalculate();
                }
            });
        });

        // collapse/expand rows-more
        const rowsCollapse = el.querySelectorAll('[data-more="1"]');
        const rowsCollapseClickCollapse = el.querySelector(".editing_entry_more_collapse");
        const rowsCollapseClickExpand = el.querySelector(".editing_entry_more_expand");
        if (rowsCollapseClickCollapse !== null && rowsCollapseClickExpand !== null && rowsCollapse.length > 0) {
            rowsCollapseClickCollapse.addEventListener("click", (e) => {
                rowsCollapse.forEach((el) => el.classList.add("is-hidden"));
                rowsCollapseClickCollapse.classList.add("is-hidden");
                rowsCollapseClickExpand.classList.remove("is-hidden");
            });
            rowsCollapseClickExpand.addEventListener("click", (e) => {
                rowsCollapse.forEach((el) => el.classList.remove("is-hidden"));
                rowsCollapseClickCollapse.classList.remove("is-hidden");
                rowsCollapseClickExpand.classList.add("is-hidden");
            });
        }

        // collapse/expand entry
        const divCollapse = el.querySelector(".editing_entry_collapse");
        el.querySelector(".editing_entry_collapse_click").addEventListener("click", (e) => {
            divCollapse.classList.toggle("is-hidden");
            that.recalculate();  // we want to save the collapse-state
        });
    },

    get_entry_list() {
        // gets list of entries
        const container = document.getElementById("editing_entry_container");
        let entries = [];
        container.querySelectorAll(".editing_entry").forEach((el) => {
            let entry = {};
            let pars = {};
            entry["id"] = el.dataset.id;
            entry["n"] = el.dataset.n;
            entry["off"] = el.querySelector(".editing_entry_active").checked ? 0 : 1;
            entry["exp"] = el.querySelector(".editing_entry_collapse").classList.contains("is-hidden") ? 0 : 1;
            if (!(entry["id"] in this.editing_entry_list)) {
                console.log("Unknown editing entry: " + entry["id"]);
                return;
            }
            const props = this.editing_entry_list[entry["id"]];
            if (props.type == "table") {
                pars = this.get_entry_pars_table(el, props.pars);
            }
            entry["pars"] = pars;
            entries.push(entry);
        });
        return entries;
    },

    get_entry_num() {
        // gets number of entries
        const container = document.getElementById("editing_entry_container");
        return container.querySelectorAll(".editing_entry").length;
    },

    get_entry_pars_table(el, pars_list) {
        const that = this;
        const pars = {};
        const n = el.dataset.n;
        // el.querySelectorAll(".editing_entry_par_input").forEach((el) => {

        for (const key in pars_list) {
            if (pars_list[key].type === "info") {
                if (key in that.info) {
                    pars[key] = that.info[key];
                }
            }
        }

        el.querySelectorAll("[data-id]").forEach((el) => {
            const key = el.dataset.id;
            if (key in pars_list === false) {
                console.log("Unknown editing entry par: " + key);
                return;
            }
            if (pars_list[key].type === "float") {
                pars[key] = el.valueAsNumber;
                if (pars[key] == null || isNaN(pars[key])) pars[key] = pars_list[key].default;
            } else if (pars_list[key].type === "select") {
                pars[key] = el.value;
            } else if (pars_list[key].type === "FT_select") {
                pars[key] = window.draw_rect_objects[n].savePoints();
            } else {
                pars[key] = el.value;
            }
        });
        return pars;
    },

    state_changed(curr_state, item) {
        var that = this;
        const res = Object.keys(curr_state).some((key) =>  {
            if (typeof curr_state[key] === "object") {
                const n1 = Object.keys(curr_state[key]).length;
                const n2 = Object.keys(item[key]).length;
                return ((n1 !== n2) || that.state_changed(curr_state[key], item[key]));
            }
            return curr_state[key] != item[key]
        });
        return res;
    },

    recalculate() {
        // console.log("recalculate: " + this.curr_id + " " + window.image_info_id + " " + this.updating);
        if (window.image_info_id != this.curr_id || this.updating) return;

        const curr_id = this.curr_id;
        const item = window.items[curr_id];
        const el_dir = document.getElementById("editing_entry_main_direction");
        const el_bg = document.getElementById("editing_entry_main_background");
        const el_ch = document.getElementById("editing_entry_main_channel");
        const el_ch2 = document.getElementById("editing_entry_main_channel2");

        var curr_state = {};
        curr_state["background_correction"] = el_bg.value;
        curr_state["edits"] = this.get_entry_list().map(x => JSON.stringify(x));
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
            window.queue_edits_range.add(curr_id, "edit", () => recalculate_item(curr_id, curr_state));
        }
    },

    get_uid() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    },

    check_input_validity(el) {
        if (el.type == "number") {
            let val = el.valueAsNumber;
            if (val == null || isNaN(val)) {
                val = parseFloat(el.dataset.default);
            }
            if ("min" in el.dataset) {
                const min =  parseFloat(el.dataset.min);
                if (val < min) {
                    val = min;
                }
            }
            if ("max" in el.dataset) {
                const max =  parseFloat(el.dataset.max);
                if (val > max) {
                    val = max;
                }
            }
            el.value = this.format_number(val, el.dataset);
        }
    },

    format_number(val, pars) {
        if ("digits" in pars) {
            const digits = parseInt(pars.digits);
            const val_str = val.toFixed(digits);
            val = val_str;
        }
        return val;
    }

}


window.editing_object = new Editing();