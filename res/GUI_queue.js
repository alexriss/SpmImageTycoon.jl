// class for queuing operations to be sent to Julia

function Queue() {
    this.queue = {};
    this.queued_ids = [];
    this.timeout = null;
    this.timeout_wait = 5;
    this.curr_id = "";
    this.curr_type = "";
    this.types_priority = {
        "edit": 1,
        "range_selected": 0,
    }
    this.julia_queue = [];
}

Queue.prototype = {
    add(id, type, func) {
        // adds an operation
        this.queued_ids.push(id);
        if (!(id in this.queue)) {
            this.queue[id] = [];
        }
        this.queue[id].push({type: type, func: func});

        console.log("add to queue: " + type);
        this.cleanup();
        this.execute();
    },

    cleanup() {
        // check if last element supercedes some of the other elements - then we either delete them or swap order
        let changes = false;

        const lq = this.queued_ids.length;
        for (let i = lq-1; i >= 0; i--) {
            const id = this.queued_ids[i];
            const lqid = this.queue[id].length;
            if (lqid > 1) {
                if (this.type_eq(this.queue[id][lqid-1].type, this.queue[id][lqid-2].type)) {
                    // superceded by the last element
                    console.log("remove from queue " + this.queue[id][lqid-2].type);
                    this.queue[id].splice(lqid-2, 1);
                    this.queued_ids.splice(i, 1);
                    changes = true;
                } else if (this.type_gt(this.queue[id][lqid-1].type, this.queue[id][lqid-2].type)) {
                    // we switch order
                    console.log("swap in queue " + this.queue[id][lqid-1].type + "  " + this.queue[id][lqid-2].type);
                    const swap = this.queue[id][lqid-1];
                    this.queue[id][lqid-1] = this.queue[id][lqid-2];
                    this.queue[id][lqid-2] = swap;
                    changes = true;
                }
            }
            if (!changes) {  // if there are no changes for the last element, we can stop
                break;
            }
        }
    },

    execute() {
        // schedules next operation
        if (this.queued_ids.length == 0) {
            return;
        }

        if (this.julia_queue.length > 0) {
            const that = this;
            window.setTimeout(() => that.execute(), that.timeout_wait);
            return;
        }

        const id = this.queued_ids.shift();
        const item = this.queue[id].shift();
        this.julia_queue.push(item.type);
        console.log("execute " + item.type);
        item.func();
    },

    type_in_queue(id, type) {
        // returns true if type is in the queue
        console.log("type: " + type);
        console.log(this.queue[id]);
        console.log(this.julia_queue);
        if (!(id in this.queue)) {
            console.log("false1");
            return false;
        }
        
        const q = this.queue[id];
        for (let i = 0; i < q.length; i++) {
            if (q.type == type) {
                console.log("true1");
                return true;
            }
        }

        const jq = this.julia_queue;
        if (jq.filter(x => x === type).length > 1) {
            // we have at least two of the same type in the queue (the first one is the active one)
            console.log("true2");
            return true;
        }
        console.log("false_end");
        return false;
    },

    queue_length(id) {
        if (!(id in this.queue)) {
            return 0;
        }
        return this.julia_queue.length + this.queue[id].length;
    },

    remove_julia_queue(type) {
        console.log("removing from julia queue: " + type + "");
        if (this.julia_queue[0] != type) {
            console.log("Job type mismatch: " + this.julia_queue[0] + " vs " + type + ")");
        }
        this.julia_queue.shift();
    },

    type_eq(type1, type2) {
        // returns true if type1 is equal type2
        return this.types_priority[type1] == this.types_priority[type2];
    },


    type_geq(type1, type2) {
        // returns true if type1 is greater or equal type2
        return this.types_priority[type1] >= this.types_priority[type2];
    },

    type_gt(type1, type2) {
        // returns true if type1 is greater than type2
        return this.types_priority[type1] > this.types_priority[type2];
    }
}

window.queue_edits_range = new Queue();