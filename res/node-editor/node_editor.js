// Node flow editor in pure JS
// inspired by:
// https://www.youtube.com/watch?v=1JNbGf8dhAQ

function NodeFlowEditor(boardElement, boardWrapperElement, onChange=null) {
    this.boardElement = boardElement;
    this.boardWrapperElement = boardWrapperElement;

    this.onChange = onChange;
    if (this.onChange === null) {
        this.onChange = () => {return;};
    }

    this.grabbingBoard = false;
    this,grabbingNode = false;
    this.grabbingNodeMoved = false;
    this.selecting = false;
    
    this.selectedNodes = new Set();
    this.clickedNodeInitialState = false;

    this.selectedEdge = null;
    this.selectedEdgeTemp = null;
    this.newEdge = null;
    this.newEdgeObj = null;

    this.insideInput = null;
    this.clickedPosition = { x: -1, y: -1 };
    
    this.nodes = [];
    this.edges = [];

    this.maxZindex = 1;

    this.clipboard = "";

    this.nodeTypes = {};

    this.setupEvents();
    this.setupNodeTypes();
    this.setupMenu();
    this.zoomDrag = new ZoomDragNodeEditor(this.boardWrapperElement, "article.node");
    this.setupSelection();
    this.addNode({typeName: "Output"}, {x: 1600, y: 1600});
}


NodeFlowEditor.prototype = {
    setupNodeTypes() {
        // setup nodeTypes object from templates
        const templates = document.querySelectorAll("#nodeTemplates template");
        for (let i = 0; i < templates.length; i++) {
            const name = templates[i].getAttribute("data-name");
            if (name === "divider") {
                this.nodeTypes["divider" + i] = "divider";
                continue;
            }
            const context = !(templates[i].getAttribute("data-context") === "false");
            const permanent = (templates[i].getAttribute("data-permanent") === "true");
            const unique = (templates[i].getAttribute("data-unique") === "true");

            this.nodeTypes[name] = {
                name: name,
                template: templates[i].id,
                context: context,
                permanent: permanent,
                unique: unique,
            };
        }
    },

    setupMenu() {
        const structure = [];
        // iterate over nodetypes object key/value pairs
        for (let [key, value] of Object.entries(this.nodeTypes)) {
            if (value === "divider") {
                structure.push('divider');
                continue;
            }
            const obj = {
                'onclick': (e) => this.handleOnClickAdd(e, key),
            }
            Object.assign(obj, value);
            structure.push(obj);
        }
        structure.push('divider');      
        structure.push({
            'name': 'Fit to view',
            'onclick': () => this.zoomDrag.adjustView(),
            'class': ['has-text-grey', 'is-italic']
        });

        const menuWrapper = document.getElementById('dropdown-menu-node-wrapper');
        this.contextMenu = new ContextMenu(this.boardElement, menuWrapper,  structure);
    },

    setupEvents() {
        this.boardElement.addEventListener("mouseup", (e) => this.handleOnMouseUpBoard(e));
        this.boardElement.addEventListener("mousedown", (e) => this.handleOnMouseDownBoard(e));
        this.boardElement.addEventListener("mousemove", (e) => this.handleOnMouseMove(e));
        this.boardElement.addEventListener("mouseleave", (e) => this.handleOnMouseUpBoard(e));
    
        // boardWrapper needs to have a tabindex attribute to be able to handle keydown events
        this.boardWrapperElement.addEventListener("keydown", (e) => {
            if (e.key === "Delete" || e.key === "Backspace") {
                for (const node of this.selectedNodes) {
                    this.handleOnClickDelete(node, e);
                }
                if (this.selectedEdge !== null) {
                    this.handleOnDeleteEdge(this.selectedEdge);
                }
                if (this.selectedEdgeTemp !== null) {
                    this.handleOnDeleteEdge(this.selectedEdgeTemp);
                }
            } else if (e.key === "Escape") {
                this.setSelectedNode(null);
                this.selectedEdge = null;
                this.selectedEdgeTemp = null;
                this.updateEdges();
            } else if (e.key === "a" && (e.ctrlKey || e.metaKey)) {
                e.preventDefault();
                this.setSelectedNode(null);
                for (let i = 0; i < this.nodes.length; i++) {
                    this.setSelectedNode(this.nodes[i], false, true);
                }
            } else if (e.key === "c" && (e.ctrlKey || e.metaKey)) {
                e.preventDefault();
                const data = this.exportData(true);
                this.clipboard = JSON.stringify(data);
            } else if (e.key === "v" && (e.ctrlKey || e.metaKey)) {
                e.preventDefault();
                if (this.clipboard.length > 0) {
                    let data = JSON.parse(this.clipboard);
                    data = this.adjustData(data);
                    this.loadData(data, false, false, false, true);
                }
            } else if (e.key === "z" && (e.ctrlKey || e.metaKey)) {
                // e.preventDefault();
                // todo: undo manager
            }
        });
    },

    // Setters
    setGrabbingBoard(value) {
        this.grabbingBoard = value;
        if (value) {
            this.boardElement.classList.add("boardDragging");
            this.zoomDrag.setMoveEnabled(true);
        } else {
            this.boardElement.classList.remove("boardDragging");
            this.zoomDrag.setMoveEnabled(false);
        }
    },

    setSelecting(value) {
        this.selecting = value;
    },

    setSelectedNodeId(id, unselect=true, switchState=false) {
        const node = this.nodes.find((node) => node.id === id);
        return this.setSelectedNode(node, unselect, switchState);
    },

    setSelectedNode(node, deselect=true, switchState=false) {
        if (node === null) {
            this.selectedNodes.clear();
        } else if (switchState && this.selectedNodes.has(node)) {
            this.selectedNodes.delete(node);
        } else {
            this.selectedNodes.add(node);
        }

        // deselect all other nodes
        if (deselect) {
            for (let i = 0; i < this.nodes.length; i++) {
                if (this.nodes[i] != node) {
                    this.selectedNodes.delete(this.nodes[i]);
                }
            }
        }

        // sync selected state
        for (let i = 0; i < this.nodes.length; i++) {
            if (this.selectedNodes.has(this.nodes[i])) {
                this.nodes[i].setSelected(true);
            } else {
                this.nodes[i].setSelected(false);
            }
        }

        return node;
    },

    updateSelectedNodes() {
        // updates selected node list based on the css classes
        this.selectedNodes.clear();
        const nodes = this.boardElement.querySelectorAll(".nodeSelected");
        for (let i = 0; i < nodes.length; i++) {
            const node = this.nodes.find((node) => node.node === nodes[i]);
            if (node) {
                this.selectedNodes.add(node);
                node.setSelected(true);
            }
        }
    },

    IsNodeAtPosition(pos, minDist=10) {
        // returns true if there is a node at the position
        for (let i = 0; i < this.nodes.length; i++) {
            if (Math.abs(pos.x - this.nodes[i].currPosition.x) < minDist &&
                Math.abs(pos.y - this.nodes[i].currPosition.y) < minDist) {
                    return true;
                }
        }
        return false;
    },

    addNode(node, offset, onTop=true) {
        if (!node.hasOwnProperty("currPosition")) {
            node.currPosition = { x: 0, y: 0 };
        } else if (typeof node.currPosition.x !== "number" || typeof node.currPosition.y !== "number") {
            node.currPosition = { x: 0, y: 0 };
        }
        node.currPosition.x += offset.x;
        node.currPosition.y += offset.y;

        while (this.IsNodeAtPosition(node.currPosition)) {
            node.currPosition.x += 20;
            node.currPosition.y += 20;
        }

        node.prevPosition = { x: node.currPosition.x, y: node.currPosition.y };

        if (!node.hasOwnProperty("id")) {
            const id = `node_${Math.random().toString(36).substring(2, 8)}`;
            node.id = id;
        }
        
        this.maxZindex++;
        const zIndex = (onTop) ? this.maxZindex : 0;

        const nodeObj = new NodeFlowEditorNode(
            this.boardElement, this.boardWrapperElement,
            this.nodeTypes[node.typeName],
            {
                ...node,
                inputEdgeIds: [],
                outputEdgeIds: [],
                onMouseDownNode: (event) => this.handleOnMouseDownNode(node.id, event),
                onMouseUpNode: (event) => this.handleOnMouseUpNode(node.id, event),
                onClickDelete: (event) => this.handleOnClickDeleteId(node.id, event),
                onDoubleClick: (event) => this.handleOnDoubleClickNode(event),
                onMouseDownOutput: (x, y, id, indO, indI) => this.handleOnMouseDownOutput(x, y, node.id, indO, indI),
                onMouseEnterInput: (x, y, id, indO, indI) => this.handleOnMouseEnterInput(x, y, node.id, indO, indI),
                onMouseLeaveInput: (id, indO, indI) => this.handleOnMouseLeaveInput(node.id, indO, indI),
                onChange: (e) => this.handleOnChange(e),
            },
            zIndex
        )
        // Update global nodes array
        this.nodes.push(nodeObj);
    },

    addEdge(edge, cleanup=true) {
        // adds egde from loaded objects

        const nodeStart = this.nodes.find((node) => node.id === edge.nodeStartId);
        const nodeEnd = this.nodes.find((node) => node.id === edge.nodeEndId);

        // dont add edge if the nodes dont exist
        if (nodeStart === undefined || nodeEnd === undefined) {
            return;
        }
        
        edge.id = `edge_${edge.nodeStartId}_${edge.nodeStartIndex}_${edge.nodeEndId}_${edge.nodeEndIndex}`;

        // dont add the same edge twice
        if (nodeStart.outputEdgeIds.includes(edge.id) && nodeEnd.inputEdgeIds.includes(edge.id)) {
            return;
        }

        if (!edge.hasOwnProperty("position") || !edge.hasOwnProperty("currStartPosition") || !edge.hasOwnProperty("currEndPosition")) {
            const refOutput = this.nodes.find((node) => node.id === edge.nodeStartId).node.querySelectorAll(".outputNode")[edge.nodeStartIndex];
            const refInput = this.nodes.find((node) => node.id === edge.nodeEndId).node.querySelectorAll(".inputNode")[edge.nodeEndIndex];

            if (refOutput === undefined || refInput === undefined) {
                return;
            }

            const outputPositionX = refOutput.getBoundingClientRect().left + Math.abs(refOutput.getBoundingClientRect().right - refOutput.getBoundingClientRect().left) / 2;
            const outputPositionY = refOutput.getBoundingClientRect().top + Math.abs(refOutput.getBoundingClientRect().bottom - refOutput.getBoundingClientRect().top) / 2;
            const inputPositionX = refInput.getBoundingClientRect().left + Math.abs(refInput.getBoundingClientRect().right - refInput.getBoundingClientRect().left) / 2;
            const inputPositionY = refInput.getBoundingClientRect().top + Math.abs(refInput.getBoundingClientRect().bottom - refInput.getBoundingClientRect().top) / 2;

            const offsetLeft = this.boardElement.getBoundingClientRect().left;
            const offsetTop = this.boardElement.getBoundingClientRect().top;
            edge.currStartPosition = {
                x: (outputPositionX - offsetLeft) / this.zoomDrag.scale,
                y: (outputPositionY - offsetTop) / this.zoomDrag.scale,
            };
            edge.currEndPosition = {
                x: (inputPositionX - offsetLeft) / this.zoomDrag.scale,
                y: (inputPositionY - offsetTop) / this.zoomDrag.scale,
            };

            edge.position = {
                x0: edge.currStartPosition.x,
                y0: edge.currStartPosition.y,
                x1: edge.currEndPosition.x,
                y1: edge.currEndPosition.y,
            };
        }

        // delete some leftover properties
        if (cleanup) {
            ["outputIndex", "inputIndex"].map((prop) => {
                if (edge.hasOwnProperty(prop)) {
                    delete edge[prop];
                }
            });
        }

        nodeStart.outputEdgeIds = [...nodeStart.outputEdgeIds, edge.id];
        nodeEnd.inputEdgeIds = [...nodeEnd.inputEdgeIds, edge.id];

        edge = {
            ...edge,
            onMouseDownEdge: () => this.handleOnMouseDownEdge(edge.id),
            onMouseOverEdge: () => this.handleOnMouseOverEdge(edge.id),
            onMouseLeaveEdge: () => this.handleOnMouseLeaveEdge(edge.id),
            onClickDelete: () => this.handleOnDeleteEdge(edge.id)
        }
        const edgeObj = new NodeFlowEditorEdge(this.boardWrapperElement, this.boardElement, edge);
        this.edges.push(edgeObj);
    },

    setNewEdge(edge) {
        this.newEdge = edge;
        const props = {
            isNew: true,
            selected: false,
            position: {
                x0: this.newEdge.currStartPosition.x,
                y0: this.newEdge.currStartPosition.y,
                x1: this.newEdge.currEndPosition.x,
                y1: this.newEdge.currEndPosition.y,
            },
        }
        Object.assign(props, this.newEdge);
        this.newEdgeObj = new NodeFlowEditorEdge(this.boardWrapperElement, this.boardElement, props);
    },

    removeNewEdge() {
        if (this.addEdgeObj !== null) {
            this.boardElement.removeChild(this.newEdgeObj.edge);
        }
        this.newEdge = null;
        this.newEdgeObj = null;
        this.setActiveInputs(); // set all active
    },

    deleteEdge(edge)  {
        this.boardElement.removeChild(edge.edge);
        this.edges = [...this.edges.filter((e) => edge.id !== e.id)];
    },

    updateEdges() {
        for (let i = 0; i < this.edges.length; i++) {
            if (this.edges[i].id == this.selectedEdge) {
                this.edges[i].selected = true;
            } else if (this.edges[i].id == this.selectedEdgeTemp) {
                this.edges[i].selected = true;
            } else {
                this.edges[i].selected = false;
            }
            this.edges[i].setStyle();
        }   
    },

    setNewEdgeCurrEndPosition(position) {
        this.newEdgecurrEndPosition = position;
        this.newEdgeObj.setPosition({
            x0: this.newEdge.currStartPosition.x,
            y0: this.newEdge.currStartPosition.y,
            x1: this.newEdgecurrEndPosition.x,
            y1: this.newEdgecurrEndPosition.y,
        });
    },

    setActiveInputs() {
        // set the specific inputs as active when creating a new edge
        if (this.newEdge === null) {
            for (let i=0; i<this.nodes.length; i++) {
                this.nodes[i].setActiveInputs(false, -1, true);
            }
        } else {
            const nodeId = this.newEdge.nodeStartId;
            const inverted = (this.newEdge.outputIndex == -1)
            const ind = inverted ? this.newEdge.inputIndex : this.newEdge.outputIndex;
            for (let i=0; i<this.nodes.length; i++) {
                if (this.nodes[i].id == nodeId) {
                    this.nodes[i].setActiveInputs(inverted, ind);
                } else {
                    this.nodes[i].setActiveInputs(inverted, -1);
                }
            }
        }
    },

    // Handlers
    handleOnChange() {
        this.onChange();
    },

    handleOnMouseDownBoard(event) {
        this.contextMenu.hideMenu();

        // Deselect node
        if (!event.shiftKey && !event.ctrlKey && !event.metaKey) {
            this.setSelectedNode(null);
        }

        // Deselect edge
        this.selectedEdge = null;
        this.updateEdges();

        // Start grabbing board
        if (!event.shiftKey && !event.ctrlKey && !event.metaKey) {
            this.setGrabbingBoard(true);
        }
        this.clickedPosition = { x: event.x, y: event.y };
    },

    handleOnMouseUpBoard() {
        this.clickedPosition = { x: -1, y: -1 };

        // // Stop grabbing board
        this.setGrabbingBoard(false);

        // If a new edge is being set and is not inside input
        if (this.newEdge !== null && this.insideInput === null) {
            this.removeNewEdge();
        }

        // If a new edge is being set and is inside input
        if (this.newEdge !== null && this.insideInput !== null) {
            let startId = this.newEdge.nodeStartId;
            let endId = this.insideInput.nodeId;
            let startIndex = this.newEdge.outputIndex;
            let endIndex = this.insideInput.inputIndex;
            if (this.newEdge.outputIndex == -1) {  // inverted edge
                [startId, endId] = [endId, startId];
                startIndex = this.insideInput.inputIndex;
                endIndex = this.newEdge.inputIndex;
            }

            // Add new edge
            edge = {
                nodeStartId: startId,
                nodeEndId: endId,
                nodeStartIndex: startIndex,
                nodeEndIndex: endIndex,
            }

            this.addEdge(edge);
            this.removeNewEdge();
            this.handleOnChange();
        }
    },

    handleOnMouseMove(event) {
        if (this.selecting) {
            return;
        }
        
        // User clicked somewhere
        if (this.clickedPosition.x >= 0 && this.clickedPosition.y >= 0) {
            // User clicked on node
            if (this.selectedNodes.size > 0) {
                this.grabbingNode = true;
                const deltaX = event.x - this.clickedPosition.x;
                const deltaY = event.y - this.clickedPosition.y;
                if (deltaX !== 0 || deltaY !== 0) {
                    this.grabbingNodeMoved = true;
                }

                for (const node of this.selectedNodes) {
                    // Update node position
                    node.setCurrPosition({
                        x: (node.prevPosition.x + deltaX) / this.zoomDrag.scale,
                        y: (node.prevPosition.y + deltaY) / this.zoomDrag.scale,
                    });

                    // Update input edges positions
                    for (let i = 0; i < node.inputEdgeIds.length; i++) {
                        const edgeId = node.inputEdgeIds[i];
                        const edge = this.edges.find((edge) => edge.id === edgeId);
                        if (edge) {
                            edge.setCurrEndPosition({
                                x: (edge.prevEndPosition.x + deltaX) / this.zoomDrag.scale,
                                y: (edge.prevEndPosition.y + deltaY) / this.zoomDrag.scale,
                            })
                        }
                    }

                    // Update output edges positions
                    for (let i = 0; i < node.outputEdgeIds.length; i++) {
                        const edgeId = node.outputEdgeIds[i];
                        const edge = this.edges.find((edge) => edge.id === edgeId);
                        if (edge) {
                            edge.setCurrStartPosition({
                                x: (edge.prevStartPosition.x + deltaX) / this.zoomDrag.scale,
                                y: (edge.prevStartPosition.y + deltaY) / this.zoomDrag.scale,
                            });
                        }
                    }
                }
            } else {
                // User clicked on board, move board (handled by zoom_drag.js)
            }
        }

        // User is setting new edge
        if (this.newEdge !== null) {
            const offsetLeft = this.boardElement.getBoundingClientRect().left;
            const offsetTop = this.boardElement.getBoundingClientRect().top;
            this.setNewEdgeCurrEndPosition({
                x: (event.x - offsetLeft) / this.zoomDrag.scale,
                y: (event.y - offsetTop) / this.zoomDrag.scale,
            });
        }
    },

    handleOnDoubleClickNode(event) {
        // Prevent click on board
        event.stopPropagation();        
    },

    handleOnMouseDownNode(id, event) {
        // Prevent click on board
        event.stopPropagation();

        if (this.selecting) {
            return;
        }
        
        this.contextMenu.hideMenu();

        // Deselect edge
        this.selectedEdge = null;
        this.updateEdges();

        // Update first click position
        this.clickedPosition = { x: event.x, y: event.y };

        // Select node, deselection happens on mouseup
        const node = this.nodes.find((node) => node.id === id);
        this.clickedNodeInitialState = node.selected;
        let deselect = (event.ctrlKey || event.shiftKey) ? false : true;
        deselect = node.selected ? false : deselect;

        this.setSelectedNode(node, deselect, false);

        this.maxZindex++;
        for (const node of this.selectedNodes) {
            // Update node position
            node.setPrevPosition({
                x: node.currPosition.x * this.zoomDrag.scale,
                y: node.currPosition.y * this.zoomDrag.scale
            });

            // this node should go on top of the others
            node.setZindex(this.maxZindex);

            // Update input edges positions
            for (let i = 0; i < node.inputEdgeIds.length; i++) {
                const edgeId = node.inputEdgeIds[i];
                const edge = this.edges.find((edge) => edge.id === edgeId);
                if (edge) {
                    edge.setPrevEndPosition({
                        x: edge.currEndPosition.x * this.zoomDrag.scale,
                        y: edge.currEndPosition.y * this.zoomDrag.scale
                    });
                }
            }

            // Update output edges positions
            for (let i = 0; i < node.outputEdgeIds.length; i++) {
                const edgeId = node.outputEdgeIds[i];
                const edge = this.edges.find((edge) => edge.id === edgeId);
                if (edge) {
                    edge.setPrevStartPosition({
                        x: edge.currStartPosition.x * this.zoomDrag.scale,
                        y: edge.currStartPosition.y * this.zoomDrag.scale
                    });
                }
            }
        }
    },

    handleOnMouseUpNode(id, event) {
        if (!this.selecting && !this.grabbingNode && this.newEdge === null) {
            const unselect = (event.ctrlKey || event.shiftKey) ? false : true;
            let switchState = (event.ctrlKey || event.shiftKey) ? true : false;
            switchState = this.clickedNodeInitialState ? switchState : false;
            this.setSelectedNodeId(id, unselect, switchState);
        } else if (this.grabbingNode && this.grabbingNodeMoved) {
            this.handleOnChange();
        }
        this.grabbingNode = false;
        this.grabbingNodeMoved = false;
    },

    handleOnClickAdd(event, typeName) {
        // Positions taking into account scale and scroll
        const offsetLeft = this.boardElement.getBoundingClientRect().left;
        const offsetTop = this.boardElement.getBoundingClientRect().top;
        const x = (event.x - offsetLeft) / this.zoomDrag.scale;
        const y = (event.y -offsetTop) / this.zoomDrag.scale;

        this.addNode({typeName: typeName}, {x: x, y: y});
        this.handleOnChange();
    },

    handleOnClickDeleteId(id, event) {
        const node = this.nodes.find((node) => node.id === id);
        this.handleOnClickDelete(node, event);
    },

    handleOnClickDelete(node, event) {
        event.stopPropagation();

        if (node.type.hasOwnProperty("permanent") && node.type.permanent) {
            return;
        }

        // Delete node edges
        const inputs = node.inputEdgeIds;
        const outputs = node.outputEdgeIds;

        // Get all unique edges to delete
        const allEdges = [...inputs, ...outputs];
        const uniqueEdges = allEdges.filter((value, index, array) => {
            return array.indexOf(value) === index;
        });

        // Delete edges from correspondent nodes data
        for (let i = 0; i < uniqueEdges.length; i++) {
            const edge = this.edges.find((edge) => edge.id === uniqueEdges[i]);
            if (edge) {
                const nodeStart = this.nodes.find((node) => node.id === edge.nodeStartId);
                const nodeEnd = this.nodes.find((node) => node.id === edge.nodeEndId);

                nodeStart.outputEdgeIds = [...nodeStart.outputEdgeIds.filter((edgeId) => edgeId !== uniqueEdges[i])];
                nodeEnd.inputEdgeIds = [...nodeEnd.inputEdgeIds.filter((edgeId) => edgeId !== uniqueEdges[i])];

                // Delete edge from global data
                this.deleteEdge(edge);
            }
        }

        // Delete node
        this.deleteNode(node);

        this.handleOnChange();
    },

    handleOnMouseDownOutput(outputPositionX, outputPositionY, nodeId, outputIndex, inputIndex) {
        this.contextMenu.hideMenu();

        if (this.selecting) {
            return;
        }
        
        // Deselect node
        this.setSelectedNode(null);

        const offsetTop = this.boardElement.getBoundingClientRect().top;
        const offsetLeft = this.boardElement.getBoundingClientRect().left;
        // Create edge position signals with updated scale value
        const prevEdgeStart = {
            x: (outputPositionX - offsetLeft) / this.zoomDrag.scale,
            y: (outputPositionY - offsetTop) / this.zoomDrag.scale,
        };
        const currEdgeStart = {
            x: (outputPositionX - offsetLeft) / this.zoomDrag.scale,
            y: (outputPositionY - offsetTop) / this.zoomDrag.scale,
        };
        const prevEdgeEnd = {
            x: (outputPositionX - offsetLeft) / this.zoomDrag.scale,
            y: (outputPositionY - offsetTop) / this.zoomDrag.scale,
        };
        const currEdgeEnd = {
            x: (outputPositionX - offsetLeft) / this.zoomDrag.scale,
            y: (outputPositionY - offsetTop) / this.zoomDrag.scale,
        };

        this.setNewEdge({
            id: "",
            nodeStartId: nodeId,
            outputIndex: outputIndex,
            inputIndex: inputIndex,
            nodeEndId: "",
            prevStartPosition: prevEdgeStart,
            currStartPosition: currEdgeStart,
            prevEndPosition: prevEdgeEnd,
            currEndPosition: currEdgeEnd,
        });

        this.setActiveInputs();
    },

    handleOnMouseEnterInput(inputPositionX, inputPositionY, nodeId, outputIndex, inputIndex) {
        if (this.selecting) {
            return;
        }

        // only connect input to output and output to input
        if (this.newEdge === null) {
            return;
        }
        if (this.newEdge.outputIndex >= 0 && inputIndex >= 0) {
            this.insideInput = { nodeId: nodeId, inputIndex: inputIndex, position: {x : inputPositionX, y: inputPositionY}};
        } else if (this.newEdge.inputIndex >=0 && outputIndex >= 0) {
            this.insideInput = { nodeId: nodeId, inputIndex: outputIndex, position: {x : inputPositionX, y: inputPositionY}};
        } else {
            this.insideInput = null;
        }
    },

    handleOnMouseLeaveInput(nodeId, inputIndex) {
        if (this.insideInput !== null && this.insideInput.nodeId === nodeId && this.insideInput.inputIndex === inputIndex) {
            this.insideInput = null;
        }
    },

    handleOnMouseDownEdge(edgeId) {
        this.contextMenu.hideMenu();

        if (this.selecting) {
            return;
        }
        
        // Deselect node
        this.setSelectedNode(null);

        // Select edge
        this.selectedEdge = edgeId;
        this.updateEdges();
    },

    handleOnMouseOverEdge(edgeId) {
        if (this.selecting) {
            return;
        }

        // Select edge
        if (this.newEdge === null) {
            this.selectedEdgeTemp = edgeId;
            this.updateEdges();
        }
    },

    handleOnMouseLeaveEdge(edgeId) {
        this.selectedEdgeTemp = null;
        this.updateEdges();
    },

    handleOnDeleteEdge(edgeId) {
        const edge = this.edges.find((e) => e.id === edgeId);

        if (edge) {
            // Delete edge from start node
            const nodeStart = this.nodes.find((n) => n.id === edge.nodeStartId);
            if (nodeStart) {
                nodeStart.outputEdgeIds = [...nodeStart.outputEdgeIds.filter((edgeId) => edgeId !== edge.id)];
            }

            // Delete edge from end node
            const nodeEnd = this.nodes.find((n) => n.id === edge.nodeEndId);
            if (nodeEnd) {
                nodeEnd.inputEdgeIds = [...nodeEnd.inputEdgeIds.filter((edgeId) => edgeId !== edge.id)];
            }

            // Delete edge from global edges array
            this.edges = [...this.edges.filter((e) => e.id !== edge.id)];
            this.deleteEdge(edge);

            this.handleOnChange();
        }
    },

    deleteNode(node, force=false) {
        // Delete node from global nodes array
        if (!force && node.type.hasOwnProperty("permanent") && node.type.permanent) {
            return;
        }
        this.nodes = [...this.nodes.filter((n) => n !== node)];
        this.selectedNodes.delete(node);

        // Delete node from board
        this.boardElement.removeChild(node.node);
    },

    exportData(selectedOnly=false) {
        // export all the node and edge data
        let nodes = this.nodes.map((node) => {
            // get parameters from node
            const params = {};
            node.node.querySelectorAll("input, select").forEach((input) => {
                params[input.name] = input.value;
            });
            return {
                id: node.id,
                type: node.type,
                currPosition: node.currPosition,
                inputEdgeIds: node.inputEdgeIds,
                outputEdgeIds: node.outputEdgeIds,
                params: params
            };
        });

        let edges = this.edges.map((edge) => {
            return {
                id: edge.id,
                nodeStartId: edge.nodeStartId,
                nodeEndId: edge.nodeEndId,
                nodeStartIndex: edge.nodeStartIndex,
                nodeEndIndex: edge.nodeEndIndex,
            };
        });

        if (selectedOnly) {
            const selectedNodeIds = [...this.selectedNodes].map((node) => node.id);
            nodes = nodes.filter((node) => selectedNodeIds.includes(node.id));
            edges = edges.filter((edge) => selectedNodeIds.includes(edge.nodeStartId) || selectedNodeIds.includes(edge.nodeEndId));
        }

        return {nodes, edges};
    },

    getNodesSpan(nodes) {
        // returns the span of the nodes
        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        nodes.map((node) => {
            minX = Math.min(minX, node.currPosition.x);
            minY = Math.min(minY, node.currPosition.y);
            maxX = Math.max(maxX, node.currPosition.x);
            maxY = Math.max(maxY, node.currPosition.y);
        });
        return {minX, minY, maxX, maxY};
    },

    adjustData(data) {
        // relabels the IDs of nodes and edges, so that they can be pasted in the same board
        // also the output node is remove (only one of them should exist)
        const dict = {}; // dictionary of old id -> new id
        let nodes = data.nodes.map((node) => {
            const id = `node_${Math.random().toString(36).substring(2, 8)}`;
            dict[node.id] = id;
            return {
                ...node,
                id: id,
            };
        });
        const edges = data.edges.map((edge) => {
            const nodeStartId = dict[edge.nodeStartId];
            const nodeEndId = dict[edge.nodeEndId];
            const id = `edge_${nodeStartId}_${edge.nodeStartIndex}_${nodeEndId}_${edge.nodeEndIndex}`;
            return {
                ...edge,
                id: id,
                nodeStartId: nodeStartId,
                nodeEndId: nodeEndId,
            };
        });

        // remove output node
        // we do not need to remove the edges, as they will only be added if the nodes exist
        nodes = nodes.filter((node) => node.type.unique !== true);

        return {nodes, edges};
    },

    getModesOffsetCenter(nodes) {
        // calculate the span of the nodes
        const {minX, minY, maxX, maxY} = this.getNodesSpan(nodes);

        const boardWidth = this.boardElement.getBoundingClientRect().width / this.zoomDrag.scale;
        const boardHeight = this.boardElement.getBoundingClientRect().height / this.zoomDrag.scale;
        const nodesWidth = maxX - minX;
        const nodesHeight = maxY - minY;

        const offsetX = (boardWidth - nodesWidth) / 2 - minX;
        const offsetY = (boardHeight - nodesHeight) / 2 - minY;
        return {x: offsetX, y: offsetY};
    },

    clearData() {
        while (this.nodes.length > 0) {
            this.deleteNode(this.nodes[0], true);
        }
        while (this.edges.length > 0) {
            this.deleteEdge(this.edges[0]);
        }
    },

    loadData(data, clear=true, centerNodes=true, adjustView=true, select=false) {
        if (data == null && typeof val !== 'object' && !hasOwnProperty(data, "nodes") && !hasOwnProperty(data, "edges")) {
            return;
        }
        
        // clear board
        if (clear) {
            this.clearData();
        }

        let offset = {x: 0, y: 0};
        if (centerNodes) {
            offset = this.getModesOffsetCenter(data.nodes);
        }
  
        // load from exported data
        let nodeIds = [];
        if (data.hasOwnProperty("nodes")) {
            nodeIds = data.nodes.map((node) => {
                this.addNode(node, offset);
                return node.id;
            });
        }
        if (data.hasOwnProperty("edges")) {
            data.edges.map((edge) => {
                this.addEdge(edge);
            });
        }

        if (adjustView) {
            this.zoomDrag.adjustView();
        }

        if (select) {
            this.setSelectedNode(null);
            for (let i = 0; i < this.nodes.length; i++) {
                if (nodeIds.includes(this.nodes[i].id)) {
                    this.setSelectedNode(this.nodes[i], false, false);
                }
            }
        }
        this.handleOnChange();
    },

    setupSelection() {
        const that = this;
        this.selectionArea = new SelectionArea({
            container: '#node-editor-boardWrapper',
            selectables: ["article.node"],
            startareas: ['#node-editor-boardWrapper'],
            boundaries: ['#node-editor-boardWrapper'],
            behaviour: {
                overlap: 'intersect',
            },
        }).on('beforestart', ({store, event}) => {
            // selection only with modifier keys
            if (!event.shiftKey && !event.ctrlKey && !event.metaKey) {
                return false;
            }
            this.setSelecting(true);
            // this.resolveSelectables();
        }).on('start', ({store, event}) => {

        }).on('move', ({store: {changed: {added, removed}}}) => {
            for (const el of added) {
                el.classList.add('nodeSelected');
            }
            for (const el of removed) {
                el.classList.remove('nodeSelected');
            }
        }).on('stop', () => {
            that.updateSelectedNodes();
            this.setSelecting(false);
        });
    }
}

function NodeFlowEditorNode(boardElement, boardWrapper, type, props, zIndex=0) {
    this.boardElement = boardElement;
    this.boardWrapper = boardWrapper;
    this.node = null;

    this.id = "";
    this.type = type;
    this.prevPosition = { x: 0, y: 0 };
    this.currPosition = { x: 0, y: 0 };
    this.numberInputs = 0;
    this.numberOutputs = 0;
    this.selected = false;
    this.zIndex = zIndex;

    this.inputEdgeIds = [];
    this.outputEdgeIds = [];

    // merge props
    Object.assign(this, props);

    this.setCurrPosition(this.currPosition);
    this.setup();
}

NodeFlowEditorNode.prototype = {
    setup() {
        const tpl = document.getElementById(this.type.template);
        const node = tpl.content.cloneNode(true);

        this.node = node.firstElementChild;
        this.node.style.transform = `translate(${this.currPosition.x}px, ${this.currPosition.y}px)`;
        this.node.addEventListener("mousedown", (e) => this.onMouseDownNode(e));
        this.node.addEventListener("mouseup", (e) => this.onMouseUpNode(e));
        this.node.addEventListener("dblclick", (e) => this.onDoubleClick(e));
        this.node.style.zIndex = this.zIndex;

        // Inputs
        const inputs = node.querySelectorAll(".inputNode");
        for (let i = 0; i < inputs.length; i++) {
            inputs[i].addEventListener("mouseenter", (e) => this.handleMouseEnterInput(inputs[i], -1, i));
            inputs[i].addEventListener("mouseleave", (e) => this.handleMouseLeaveInput(i));
            inputs[i].addEventListener("mousedown", (e) => this.handleMouseDownOutput(inputs[i], e, -1, i));
        }

        // Outputs
        const outputs = node.querySelectorAll(".outputNode");
        for (let i = 0; i < outputs.length; i++) {
            outputs[i].addEventListener("mouseenter", (e) => this.handleMouseEnterInput(outputs[i], i, -1));
            outputs[i].addEventListener("mouseleave", (e) => this.handleMouseLeaveInput(i));
            outputs[i].addEventListener("mousedown", (e) => this.handleMouseDownOutput(outputs[i], e, i, -1));
        }

        // Delete button
        const deleteButton = node.querySelector(".delete");
        if (this.type.hasOwnProperty("permanent") && this.type.permanent) {
            deleteButton.style.display = "none";
        } else {
            deleteButton.addEventListener("click", (e) => this.onClickDelete(e));
        }

        // parameters and events for inputs
        if (!this.hasOwnProperty("params")) {
            this.params = {};
        }
        if (!this.hasOwnProperty("options")) {
            this.options = {};
        }
        const inputEls = this.node.querySelectorAll("input, select");
        for (let i = 0; i < inputEls.length; i++) {
            const name = inputEls[i].name;
            if (inputEls[i].tagName === "SELECT" && this.options.hasOwnProperty(name)) {
                // set select options
                for (let j = 0; j < this.options[name].length; j++) {
                    const option = document.createElement("option");
                    option.value = this.options[name][j];
                    option.innerHTML = this.options[name][j];
                    inputEls[i].appendChild(option);
                }
            }
            if (this.params.hasOwnProperty(name)) {
                inputEls[i].value = this.params[name];
            }

            inputEls[i].addEventListener("change", (e) => this.onChange(e));
        }


        // Add node to board
        this.boardElement.appendChild(node);
    },

    // Setters
    setCurrPosition(position) {
        this.currPosition = { x: position.x, y: position.y };
        if (this.node !== null) {
            this.node.style.transform = `translate(${position.x}px, ${position.y}px)`;
        }
    },

    setPrevPosition(position) {
        this.prevPosition = { x: position.x, y: position.y };
    },

    setSelected(selected) {
        this.selected = selected;
        if (this.selected) {
            this.node.classList.add("nodeSelected");
        } else {
            this.node.classList.remove("nodeSelected");
        }
    },

    setZindex(zindex) {
        this.node.style.zIndex = zindex;
    },

    setActiveInputs(inverted=false, currOutputIndex=-1, allActive=false) {
        let inputs = this.node.querySelectorAll(".inputNode");
        let outputs = this.node.querySelectorAll(".outputNode");

        if (allActive) {
            for (let i = 0; i < inputs.length; i++) {
                inputs[i].classList.remove("disabled");
            }
            for (let i = 0; i < outputs.length; i++) {
                outputs[i].classList.remove("disabled");
            }
        } else {
            if (inverted) {
                [inputs, outputs] = [outputs, inputs];
            }

            for (let i = 0; i < inputs.length; i++) {
                if (currOutputIndex == -1) {
                    inputs[i].classList.remove("disabled");
                } else {  // the inputs of the current node should be inactive
                    inputs[i].classList.add("disabled");
                }
            }
            for (let i = 0; i < outputs.length; i++) {
                if (i == currOutputIndex) {
                    outputs[i].classList.remove("disabled");
                } else {
                    outputs[i].classList.add("disabled");
                }
            }
        }
    },

    // handlers
    handleMouseDownOutput(ref, event, outputIndex, inputIndex) {
        // Disable drag node
        event.stopPropagation();

        const rect = ref.getBoundingClientRect();
        const centerX = rect.left + Math.abs(rect.right - rect.left) / 2;
        const centerY = rect.top + Math.abs(rect.bottom - rect.top) / 2;
        this.onMouseDownOutput(centerX, centerY, this.id, outputIndex, inputIndex);
    },

    handleMouseEnterInput(ref, outputIndex, inputIndex) {
        const rect = ref.getBoundingClientRect();
        const centerX = rect.left + Math.abs(rect.right - rect.left) / 2;
        const centerY = rect.top + Math.abs(rect.bottom - rect.top) / 2;
        this.onMouseEnterInput(centerX, centerY, this.id, outputIndex, inputIndex);
    },

    handleMouseLeaveInput(inputIndex) {
        this.onMouseLeaveInput(this.id, inputIndex);
    }
}


function NodeFlowEditorEdge(boardWrapper, board, props) {
    this.boardWrapper = boardWrapper;
    this.board = board;
    this.edge = null;

    this.selected = false;
    this.isNew = false;
    this.position = { x0: 0, y0: 0, x1: 0, y1: 0 };

    this.outputIndex = -1;
    this.inputIndex = -1;

    // merge props
    Object.assign(this, props);

    const middleX = (this.position.x0 + this.position.x1) / 2;
    const middleY = (this.position.y0 + this.position.y1) / 2;
    this.middlePoint = { x: middleX, y: middleY };
    this.setup();
}

NodeFlowEditorEdge.prototype = {
    setup() {
        const tpl = document.getElementById("edgeTemplate");
        const edge = tpl.content.cloneNode(true);
        this.edge = edge.firstElementChild;

        this.path = edge.querySelector("path");
        this.deleteButton = edge.querySelector(".deleteButton");
        
        this.deleteButton.addEventListener("click", (e) => this.handleOnClickDelete(e));
        this.path.addEventListener("mousedown", (e) => this.handleOnMouseDownEdge(e));
        this.edge.addEventListener("mouseover", (e) => this.handleOnMouseOverEdge(e));
        this.edge.addEventListener("mouseleave", (e) => this.handleOnMouseLeaveEdge(e));

        this.setPosition(this.position);
        this.setSelectedNew(this.selected, this.isNew);

        this.setStyle();
        // Add edge to board
        this.board.appendChild(edge);
    },

    // Setters
    setStyle() {
        if (this.isNew) {
            this.path.classList.add("edgeNew");
            this.path.classList.remove("edge");
            this.path.classList.remove("edgeSelected");
        } else if (this.selected) {
            this.path.classList.add("edgeSelected");
            this.path.classList.remove("edge");
            this.path.classList.remove("edgeNew");
            this.deleteButton.classList.add("delete");
            this.deleteButton.classList.remove("deleteHidden");
        } else {
            this.path.classList.add("edge");
            this.path.classList.remove("edgeSelected");
            this.path.classList.remove("edgeNew");
            this.deleteButton.classList.add("deleteHidden");
            this.deleteButton.classList.remove("delete");
        }
    },

    setMiddlePoint() {
        let x = this.position.x0 + (this.position.x1 - this.position.x0) / 2;
        let y = this.position.y0 + (this.position.y1 - this.position.y0) / 2;

        this.middlePoint = { x: x, y: y };
        if (this.selected) {
            y -= 24;
        }
        this.deleteButton.setAttribute('transform', `translate(${x} ${y})`);
    },

    setSelectedNew(selected, isNew) {
        this.selected = selected;
        this.isNew = isNew;
        this.setStyle();
    },

    setCurrEndPosition(position) {
        this.currEndPosition = { x: position.x, y: position.y };
        this.setPosition({
            x0: this.currStartPosition.x,
            y0: this.currStartPosition.y,
            x1: this.currEndPosition.x,
            y1: this.currEndPosition.y,
        });
    },

    setCurrStartPosition(position) {
        this.currStartPosition = { x: position.x, y: position.y };
        this.setPosition({
            x0: this.currStartPosition.x,
            y0: this.currStartPosition.y,
            x1: this.currEndPosition.x,
            y1: this.currEndPosition.y,
        });
    },

    setPrevEndPosition(position) {
        this.prevEndPosition = { x: position.x, y: position.y };
    },

    setPrevStartPosition(position) {
        this.prevStartPosition = { x: position.x, y: position.y };
    },

    setPosition(position) {
        this.position = position;

        let offset = this.calculateOffset(Math.abs(position.x1 - position.x0));
        if (this.isNew && this.outputIndex == -1) {
            offset = -offset;
        }

        this.path.setAttribute("d", `
        M ${position.x0} ${position.y0} C ${
            position.x0 + offset
        } ${position.y0}, ${position.x1 - offset } ${
            position.y1
        }, ${position.x1} ${position.y1}`
        );

        this.setMiddlePoint();
    },

    // Give the edge a little offset so it curves
    calculateOffset(value) {
        return value / 2;
    },

    // Handlers
    handleOnMouseDownEdge(event) {
        // Disable click on board event
        event.stopPropagation();
        this.onMouseDownEdge();
    },

    handleOnMouseOverEdge(event) {
        this.onMouseOverEdge();
    },

    handleOnMouseLeaveEdge(event) {
        this.onMouseLeaveEdge();
    },

    handleOnClickDelete(event) {
        // Disable click on board event
        event.stopPropagation();
        this.onClickDelete();
    }

}
