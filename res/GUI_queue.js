// class for queuing operations to be sent to Julia

function Queue() {
    this.queue = {};
    this.queued_ids = [];
    this.julia_queue = {};
    this.timeout = null;
    this.timeout_wait = 5;
    this.types_priority = {
        "edit": 1,
        "range_selected": 0,
    }
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
    },

    execute() {
        // schedules next operation
        if (this.queued_ids.length == 0) {
            return;  // nothing to do
        }

        const id = this.queued_ids[0];
        const item = this.queue[id][0];

        if (!(id in this.julia_queue)) {
            this.julia_queue[id] = [];
        }

        if (this.julia_queue[id].length > 0) {
            const that = this;
            window.setTimeout(() => that.execute(), that.timeout_wait);
            return;
        }

        this.queued_ids.shift();
        this.queue[id].shift();
        this.julia_queue[id].push(item.type);

        item.func();
    },

    type_in_queue(id, type) {
        // returns true if type is in the queue
        if (id in this.queue) {
            const q = this.queue[id];
            for (let i = 0; i < q.length; i++) {
                if (q[i].type === type) {
                    return true;
                }
            }
        }

        if (id in this.julia_queue) {
            const jq = this.julia_queue[id];
            if (jq.filter(x => x === type).length > 1) {
                // we have at least two of the same type in the queue (the first one is the active one)
                return true;
            }
        }
        return false;
    },

    queue_length(id) {
        let sum = 0;
        if (id in this.queue) {
            sum += this.queue[id].length;
        }
        if (id in this.julia_queue) {
            sum += this.julia_queue[id].length;
        }
        return sum;
    },

    remove_julia_queue(ids, type) {
        for (let i = 0; i < ids.length; i++) {
            const id = ids[i];
            if (!(id in this.julia_queue)) {
                console.log("Job id mismatch: " + id + " not found.");
                continue;
            }
            if (this.julia_queue[id].length === 0) {
                console.log("Job queue mismatch: " + id + " had no scheduled jobs.");
                continue;
            }
            const julia_type = this.julia_queue[id].shift();
            if (julia_type != type) {
                console.log("Job type mismatch: " + this.julia_queue[id][0] + " vs " + type + ")");
            }
        }
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