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
        "contrast": 0,
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
                    this.queue[id].splice(lqid-2, 1);
                    this.queued_ids.splice(i, 1);
                    changes = true;
                } else if (this.type_gt(this.queue[id][lqid-1].type, this.queue[id][lqid-2].type)) {
                    // we switch order
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
        const id = this.queued_ids[lq-1];
        console.log(this.queue[id]);
        console.log(changes);
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
        item.func();
    },

    remove_julia_queue(type) {
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

window.queue_edits_contrast = new Queue();