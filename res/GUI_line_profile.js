function LineProfile(canvas_element, img_element) {
    this.canvas = canvas_element;
    this.img = img_element;
    this.ctx = this.canvas.getContext("2d");
    this.first_setup = false;
    this.first_setup_events = false;

    this.Point2 = (x, y) => ({ x, y });  // creates a point
    this.Line = (p1, p2) => ({ p1, p2 });
    this.setStyle = (style) => this.eachOf(Object.keys(style), key => { this.ctx[key] = style[key] });
    this.eachOf = (array, callback) => { var i = 0; while (i < array.length && callback(array[i], i++) !== true); };
    this.list = {
        items: null,
        add(item) { this.items.push(item); return item },
        eachItem(callback) {
            var i = 0;
            while (i < this.items.length) {
                callback(this.items[i], i++);
            }
        }
    }

    this.points = this.createList({
        getClosest: this.getClosestPoint,
        draw: this.drawPoints,
    });

    this.lines = this.createList({
        getClosest: this.getClosestline,
        draw: this.drawLines,
    });

    this.mouse = { x: 0, y: 0, button: false, drag: false, dragStart: false, dragEnd: false, dragStartX: 0, dragStartY: 0 }

    // short cut vars
    this.w = this.canvas.width;
    this.h = this.canvas.height;
    this.cw = this.w / 2;  // center
    this.ch = this.h / 2;
    this.maxSideLength = 1600;  // pixel resolution of canvas
    this.maxNumberLines = 1;
    this.globalTime;
    this.closestLine;
    this.closestPoint;
    this.pointDrag; // true is dragging a point else dragging a line
    this.dragOffsetX;
    this.dragOffsetY;
    this.cursor;
    this.toolTip;
    this.helpCount = 0;
    this.minDist = 20;
    this.lineStyle = {
        lineWidth: 5,
        strokeStyle: "#1ad1b3",
    }
    this.pointStyle = {
        lineWidth: 3,
        strokeStyle: "#4090cd",
    }
    this.highlightStyle = {
        lineWidth: 8,
        strokeStyle: "#ef4568",
    }
    this.font = {
        font: "18px arial",
        fillStyle: "black",
        textAlign: "center",
    }
}


LineProfile.prototype = {
    createList(extend) {
        return Object.assign({}, this.list, { items: [] }, extend);
    },

    // removes first line and associated points
    removeFirst() { 
        this.lines.items.shift();
        this.points.items.shift();
        this.points.items.shift();
        this.lines.eachItem(l => {
            l.p1 = l.p1 - 2;
            l.p2 = l.p2 - 2;
        });
    },

    // this will extend the points list
    getClosestPoint(from, minDist) {
        var closestPoint;
        this.eachItem(point => {
            const dist = Math.hypot(from.x - point.x, from.y - point.y);
            if (dist < minDist) {
                closestPoint = point;
                minDist = dist;
            }
        });
        return closestPoint;
    },

    distanceLineFromPoint(line, point) {
        const lx = this.points.items[line.p1].x;
        const ly = this.points.items[line.p1].y;
        const v1x = this.points.items[line.p2].x - lx;
        const v1y = this.points.items[line.p2].y - ly;
        const v2x = point.x - lx;
        const v2y = point.y - ly;
        // get unit dist of closest point
        const u = (v2x * v1x + v2y * v1y) / (v1y * v1y + v1x * v1x);
        if (u >= 0 && u <= 1) {  // is the point on the line
            return Math.hypot(lx + v1x * u - point.x, ly + v1y * u - point.y);
        } else if (u < 0) {  // point is before start
            return Math.hypot(lx - point.x, ly - point.y);
        }
        // point is after end of line
        return Math.hypot(this.points.items[line.p2].x - point.x, this.points.items[line.p2].y - point.y);
    },

    // this will extend the lines list
    getClosestline(from, minDist) {
        var closestLine;
        this.eachItem(line => {
            const dist = window.line_profile_object.distanceLineFromPoint(line, from);
            if (dist < minDist) {
                closestLine = line;
                minDist = dist;
            }
        });
        return closestLine;
    },

    drawPoint(point) {
        this.ctx.moveTo(point.x, point.y);
        this.ctx.rect(point.x - 2, point.y - 2, 4, 4);

    },

    drawLine(line) {
        this.ctx.moveTo(this.points.items[line.p1].x, this.points.items[line.p1].y);
        this.ctx.lineTo(this.points.items[line.p2].x, this.points.items[line.p2].y);
    },

    drawLines() { this.eachItem(line => window.line_profile_object.drawLine(line)) },  // otherwise the "this" is the subobject

    drawPoints() { this.eachItem(point => window.line_profile_object.drawPoint(point)) },  // otherwise the "this" is the subobject

    getMousePos(canvas, evt) {
        var rect = canvas.getBoundingClientRect();
        return {
            x: (evt.clientX - rect.left) / (rect.right - rect.left) * canvas.width,
            y: (evt.clientY - rect.top) / (rect.bottom - rect.top) * canvas.height
        };
    },

    // converts points on the canvas to scansize units
    pointsToNm(point, imgScansize) {
        return this.Point2(point.x / this.w * imgScansize[0], (this.h - point.y) / this.h * imgScansize[1]);
    },

    // converts nm units to points on the canvas
    nmToPoints(pointNm, imgScansize) {
        return this.Point2(pointNm.x / imgScansize[0] * this.w, this.h - pointNm.y / imgScansize[1] * this.h);
    },

    mouseEvents(e) {
        //this.mouse.x = e.pageX;
        //this.mouse.y = e.pageY;
        if (e.shiftKey || e.ctrlKey) {
            return;  // modifier keys will be used for dragging
        }
        var mousepos = this.getMousePos(this.canvas, e)
        this.mouse.x = mousepos.x;
        this.mouse.y = mousepos.y;
        const lb = this.mouse.button;
        this.mouse.button = e.type === "mousedown" ? true : e.type === "mouseup" ? false : this.mouse.button;
        if (lb !== this.mouse.button) {
            if (this.mouse.button) {
                this.mouse.drag = true;
                this.mouse.dragStart = true;
                this.mouse.dragStartX = this.mouse.x;
                this.mouse.dragStartY = this.mouse.y;
            } else {
                this.mouse.drag = false;
                this.mouse.dragEnd = true;
                this.showInfo();
            }
        }
        if (this.mouse.drag) {
            this.showInfo();
        }
    },

    // handles changes in input fields
    inputEvents(e) {
        const id = e.target.id;
        const el = document.getElementById(id);
        const elVal = parseFloat(el.value);
        if (Number.isNaN(elVal)) {
            this.showInfo();
            return;
        }
        const img = window.items[window.zoom_last_selected];
        const imgScansize = img.scansize;
        var p = this.Point2(0, 0);


        if (id == "line_profile_start_x") {
            p.x = elVal;
            this.points.items[0].x = this.nmToPoints(p, imgScansize).x;
        } else if (id == "line_profile_start_y") {
            p.y = elVal;
            this.points.items[0].y = this.nmToPoints(p, imgScansize).y;
        } else if (id == "line_profile_end_x") {
            p.x = elVal;
            this.points.items[1].x = this.nmToPoints(p, imgScansize).x;
        } else if (id == "line_profile_end_y") {
            p.y = elVal;
            this.points.items[1].y = this.nmToPoints(p, imgScansize).y;
        } else if (id == "line_profile_length") {
            var newLength = elVal;
            if (newLength <= 0) {
                newLength = 0.0001;
            }
            const startNm = this.pointsToNm(this.points.items[0], imgScansize);
            var endNm = this.pointsToNm(this.points.items[1], imgScansize);
            const lineLength = Math.sqrt((endNm.x - startNm.x)**2 + (endNm.y - startNm.y)**2);
            endNm.x = startNm.x + (endNm.x - startNm.x) / lineLength * newLength;
            endNm.y = startNm.y + (endNm.y - startNm.y) / lineLength * newLength;
            this.points.items[1] = this.nmToPoints(endNm, imgScansize);
        } else if (id == "line_profile_angle") {
            const startNm = this.pointsToNm(this.points.items[0], imgScansize);
            var endNm = this.pointsToNm(this.points.items[1], imgScansize);
            const lineLength = Math.sqrt((endNm.x - startNm.x)**2 + (endNm.y - startNm.y)**2);
            endNm.x = startNm.x + Math.cos(elVal / 180 * Math.PI) * lineLength;
            endNm.y = startNm.y + Math.sin(elVal / 180 * Math.PI) * lineLength;
            this.points.items[1] = this.nmToPoints(endNm, imgScansize);
        }
        this.showInfo();
    },

    // check if sizes are ok
    checkSanity() {
        var elErrSize = document.getElementById("line_profile_error_size");
        if (this.img.clientWidth != this.canvas.clientWidth || this.img.clientHeight != this.canvas.clientHeight) {
            elErrSize.classList.remove("is-hidden");
        } else {
            elErrSize.classList.add("is-hidden");
        }
    },

    // show info in sidebar
    showInfo() {
        this.checkSanity();
        if (this.points.items.length < 2) {
            return;
        }

        const img = window.items[window.zoom_last_selected];

        const elStartX = document.getElementById("line_profile_start_x");
        const elStartY = document.getElementById("line_profile_start_y");
        const elStartValue = document.getElementById("line_profile_start_value");
        const elEndX = document.getElementById("line_profile_end_x");
        const elEndY = document.getElementById("line_profile_end_y");
        const elEndValue = document.getElementById("line_profile_end_value");
        const elLength = document.getElementById("line_profile_length");
        const elWidth = document.getElementById("line_profile_width");
        const elAngle = document.getElementById("line_profile_angle");
        const elAngleGlobal = document.getElementById("line_profile_angle_global");

        const imgScansize = img.scansize;
        const imgAngle = img.angle;

        // in the images 0,0 is lower left corner, for the canvas points 0,0 is upper left corner
        // we only care about the first two points, i.e. the first line
        const startNm = this.pointsToNm(this.points.items[0], imgScansize);
        const endNm = this.pointsToNm(this.points.items[1], imgScansize);
        const lineLength = Math.sqrt((endNm.x - startNm.x)**2 + (endNm.y - startNm.y)**2);
        var lineAngle = Math.atan2((endNm.y - startNm.y), (endNm.x - startNm.x)) * 180 / Math.PI;
        if (lineAngle < 0) {
            lineAngle = lineAngle + 360;
        }

        elStartX.value = startNm.x.toFixed(2);
        elEndX.value = endNm.x.toFixed(2);
        elStartY.value = startNm.y.toFixed(2);
        elEndY.value = endNm.y.toFixed(2);
        elLength.value = lineLength.toFixed(2);
        elAngle.value = lineAngle.toFixed(1);
        elAngleGlobal.innerText = (lineAngle + imgAngle).toFixed(1);
    },

    // main update function
    update(timer) {
        that = window.line_profile_object;  // requestAnimationFrame sends a different "this"
        that.cursor = "crosshair";
        that.toolTip = that.helpCount < 2 ? "Click drag to create a line" : "";
        that.globalTime = timer;
        that.ctx.setTransform(1, 0, 0, 1, 0, 0); // reset transform
        that.ctx.globalAlpha = 1;           // reset alpha
        // if (that.w !== innerWidth || that.h !== innerHeight) {
        //     that.cw = (that.w = that.canvas.width = innerWidth) / 2;
        //     that.ch = (that.h = that.canvas.height = innerHeight) / 2;
        // } else {
        //     that.ctx.clearRect(0, 0, that.w, that.h);
        // }
        that.ctx.clearRect(0, 0, that.w, that.h);
        if (that.mouse.drag === false) {
            that.closestLine = undefined;
            that.closestPoint = that.points.getClosest(that.mouse, that.minDist);
            if (that.closestPoint === undefined) {
                that.closestLine = that.lines.getClosest(that.mouse, that.minDist);
            }
            if (that.closestPoint || that.closestLine) {
                // that.toolTip = "Click drag to move " + (that.closestPoint ? "point" : "line");
                that.cursor = "move";
            }
        }
        if (that.mouse.dragStart) {
            if (that.closestPoint) {
                that.dragOffsetX = that.closestPoint.x - that.mouse.x;
                that.dragOffsetY = that.closestPoint.y - that.mouse.y;
                that.pointDrag = true;

            } else if (that.closestLine) {
                that.dragOffsetX = that.points.items[that.closestLine.p1].x - that.mouse.x;
                that.dragOffsetY = that.points.items[that.closestLine.p1].y - that.mouse.y;
                that.pointDrag = false;

            } else {
                that.points.add(that.Point2(that.mouse.x, that.mouse.y));
                that.closestPoint = that.points.add(that.Point2(that.mouse.x, that.mouse.y));
                that.closestLine = that.lines.add(that.Line(that.points.items.length - 2, that.points.items.length - 1));
                that.dragOffsetX = 0;
                that.dragOffsetY = 0;
                that.pointDrag = true;
                that.helpCount += 1;
                while (that.lines.items.length > that.maxNumberLines) {
                    that.removeFirst();
                }
            }
            that.mouse.dragStart = false;

        } else if (that.mouse.drag) {
            that.cursor = 'none';
            if (that.pointDrag) {
                that.closestPoint.x = that.mouse.x + that.dragOffsetX;
                that.closestPoint.y = that.mouse.y + that.dragOffsetY;
            } else {
                const dx = that.mouse.x - that.mouse.dragStartX;
                const dy = that.mouse.y - that.mouse.dragStartY;
                that.mouse.dragStartX = that.mouse.x;
                that.mouse.dragStartY = that.mouse.y;
                that.points.items[that.closestLine.p1].x += dx;
                that.points.items[that.closestLine.p1].y += dy;
                that.points.items[that.closestLine.p2].x += dx;
                that.points.items[that.closestLine.p2].y += dy;
            }
        } else {

        }
        // draw all points and lines
        that.setStyle(that.lineStyle);
        that.ctx.beginPath();
        that.lines.draw();
        that.ctx.stroke();
        that.setStyle(that.pointStyle);
        that.ctx.beginPath();
        that.points.draw();
        that.ctx.stroke();

        // draw highlighted point or line
        that.setStyle(that.highlightStyle);
        that.ctx.beginPath();
        if (that.closestLine) { that.drawLine(that.closestLine) }
        if (that.closestPoint) { that.drawPoint(that.closestPoint) }

        that.ctx.stroke();

        // if (that.helpCount < 2) {
        //     that.setStyle(that.font);
        //     that.ctx.fillText(that.toolTip, that.cw, 30);
        // }

        that.canvas.style.cursor = that.cursor;
        // if (that.helpCount < 5) {
        //     that.canvas.title = that.toolTip;
        // } else {
        //     that.canvas.title = "";
        // }

        if (window.sidebar_imagezoomtools && !document.getElementById("line_profile").classList.contains("is-hidden")) {
            requestAnimationFrame(that.update);
        } else {
            that.unsetup()
        }
    },

    unsetup() {
        this.canvas.style.visibility = "hidden";
    },

    setup(new_image=false) {
        if (window.sidebar_imagezoomtools && !document.getElementById("line_profile").classList.contains("is-hidden")) {
            this.canvas.style.left = window.getComputedStyle(this.img).left;
            this.canvas.style.top = window.getComputedStyle(this.img).top;
            this.canvas.style.width = window.getComputedStyle(this.img).width;
            this.canvas.style.height = window.getComputedStyle(this.img).height;
            this.canvas.style.visibility = "visible";

            var scanUnit = window.items[window.zoom_last_selected].scansize_unit;
            document.getElementById("line_profile_start_unit").innerText = scanUnit;
            document.getElementById("line_profile_end_unit").innerText = scanUnit;
            document.getElementById("line_profile_width_unit").innerText = scanUnit;
            document.getElementById("line_profile_length_unit").innerText = scanUnit;
            document.getElementById("line_profile_start_value_unit").innerText = scanUnit;
            document.getElementById("line_profile_end_value_unit").innerText = scanUnit;

            var channelUnit = window.items[window.zoom_last_selected].channel_unit;
            document.getElementById("line_profile_start_value_unit").innerText = channelUnit;
            document.getElementById("line_profile_end_value_unit").innerText = channelUnit;

            var angle = window.items[window.zoom_last_selected].angle;
            if (angle != 0) {
                document.getElementById("line_profile_angle_global").classList.remove("is-hidden");
                document.getElementById("line_profile_angle_global_unit").classList.remove("is-hidden");
            } else {
                document.getElementById("line_profile_angle_global").classList.add("is-hidden");
                document.getElementById("line_profile_angle_global_unit").classList.add("is-hidden");
            }

            if (!this.first_setup || new_image) {
                let w = this.img.width;
                let h = this.img.height;
                let maxSideLength = Math.max(this.maxSideLength, Math.max(w, h));
                if (w >= h) {
                    this.canvas.width = maxSideLength;
                    this.canvas.height = maxSideLength * h/w;
                } else {
                    this.canvas.height = maxSideLength;
                    this.canvas.width = maxSideLength * w/h;
                }
                this.w = this.canvas.width;
                this.h = this.canvas.height;
                this.cw = this.w / 2;  // center
                this.ch = this.h / 2;
                this.first_setup = true;
            }
            if (!this.first_setup_events) {
                ["down", "up", "move"].forEach(name => this.canvas.addEventListener("mouse" + name, (e) => this.mouseEvents(e)));
                this.first_setup_events = true;
                const that = this;
                document.querySelectorAll("#table_line_profile input").forEach((el) => {
                    el.addEventListener("change", (e) => {
                        that.inputEvents(e);
                    });
                });
            }
            this.showInfo();
            requestAnimationFrame(this.update);
        } else {
            this.unsetup();
        }
    }
}

