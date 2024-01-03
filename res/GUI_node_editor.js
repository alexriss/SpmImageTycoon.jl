function NodeEditorInterface() {
    this.nodeEditor = null;
}

NodeEditorInterface.prototype = {
    initialize(clear=false) {
        if (this.nodeEditor === null) {
            this.nodeEditor = new NodeFlowEditor(document.getElementById("node-editor-board"), document.getElementById("node-editor-boardWrapper"));
        }
        if (clear) {
            this.nodeEditor.clearData();
        }
    },

    create() {
        // switches from grid view to imagezoom view and opens the node editor
        if (get_view() != "grid") {
            return;
        }

        // make sure the node editor is setup
        this.initialize(clear=true);
    
        let ids = get_active_element_ids();
        ids = ids.filter(id => window.items[id].type == "SpmGridSpectrum");
        if (ids.length > 0) {
            let channel_name = window.items[ids[0]].channel_name;
            let channel2_name = window.items[ids[0]].channel2_name;
            ids = ids.filter(id => window.items[id].channel_name == channel_name && window.items[id].channel2_name == channel2_name);
        }

        let item;
        for (let i=0; i<ids.length; i++) {
            // create new node
            item = window.items[ids[i]];
            this.nodeEditor.addNode(
                {
                    typeName: "Input",
                    options: {
                        filename_original: [item.filename_original],
                        channel_name: [item.channel_name],
                        channel2_name: [item.channel2_name]
                    },
                    params: {
                        filename_original: item.filename_original,
                        channel_name: item.channel_name,
                        channel2_name: item.channel2_name
                    }
                },
                {x: 850, y: i*150 + 800}
            );
        }

        this.nodeEditor.addNode({typeName: "Output"}, {x: 1600, y: ids.length * 150 / 2 - 50 + 800});

        const id = "::node-editor::";

        this.setVisible();
        toggle_imagezoom("zoom", id, true);
    },

    setVisible(visible=true) {
        if (visible) {
            document.getElementById("node-editor-boardWrapper").classList.remove("is-hidden");
        } else {
            document.getElementById("node-editor-boardWrapper").classList.add("is-hidden");
        }
    },

    toggleVisible() {
        document.getElementById("node-editor-boardWrapper").classList.toggle("is-hidden");
    }
}

window.node_editor_interface = new NodeEditorInterface();