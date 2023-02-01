function Editing() {

}


Editing.prototype = {
    setup_form(id, extra_info) {
        this.setup_form_main_entry(id, extra_info);
        this.setup_form_entries(id, extra_info);
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
            this.add_options(el_dir, window.directions_list["spectrum"], item.scan_direction);
            this.add_options(el_bg, window.background_corrections["image"], item.background_correction);
            this.add_options(el_ch, channels, item.channel_name);
            editing_entry_main_channel2_row.classList.remove("is-hidden");
            this.add_options(el_ch2, channels, item.channel_name2);
        } else if (item.type == "SpmGridImage") {
            let dir = (item.channel_name.endsWith(" bwd")) ? 1 : 0;
            let channel = item.channel_name.replace(" bwd", "");
            this.add_options(el_dir, window.directions_list["image"], dir);
            this.add_options(el_bg, window.background_corrections["image"], item.background_correction);
            this.add_options(el_ch, channels, channel);
            editing_entry_main_channel2_row.classList.add("is-hidden");
        }
    },

    setup_form_entries(id, extra_info) {
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
     }

}


window.editing_object = new Editing();