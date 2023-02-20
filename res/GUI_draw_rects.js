function DrawRects(canvas_element, img_element) {
    var self = this;
    this.canvas = canvas_element;
    this.img = img_element;
    this.ctx = this.canvas.getContext("2d");
    this.first_setup = false;
    this.first_setup_events = false;

    this.imgScansize = [0, 0]  // needed for conversions etc
    this.unit_prefix = "";  // prefix for unit (i.e. m, µ, p, f, ...)
    this.unit_exponent = 0;  // exonent for the unit

    this.Point2 = (x, y) => ({ x, y });  // creates a point
    this.setStyle = (style) => this.eachOf(Object.keys(style), key => { this.ctx[key] = style[key] });
    this.eachOf = (array, callback) => { var i = 0; while (i < array.length && callback(array[i], i++) !== true); };
    this.createList = (extend) => { return Object.assign({}, this.list, { items: [] }, extend) };

    this.list = {
        items: null,
        add(item) { this.items.push(item); return item },
        del(i, n = 1) { this.items.splice(i, n); },
        eachItem(callback) {
            var i = 0;
            while (i < this.items.length) {
                callback(this.items[i], i++);
            }
        }
    }

    this.points = this.createList({
        getClosest: this.getClosestPoint,
        getClosestRect: this.getClosestRect,
        draw: this.drawPoints,
        drawRects: this.drawRects,
        eachRect: this.eachRect,
    });

    this.mouse = { x: 0, y: 0, button: false, drag: false, dragStart: false, dragEnd: false, dragStartX: 0, dragStartY: 0 }

    this.w = this.canvas.width;
    this.h = this.canvas.height;
    this.cw = this.w / 2;  // center 
    this.ch = this.h / 2;
    this.globalTime;
    this.pointDrag; // true is dragging a point else dragging a rect
    this.closestRect = {};
    this.closestPoint = {};
    this.dragOffsetX;
    this.dragOffsetY;
    this.cursor;
    this.toolTip;
    this.helpCount = 0;
    this.delRect = false;
    this.minDistPoint = 20;
    this.minDistRect = 5;
    this.rectStyle = {
        rectWidth: 2,
        strokeStyle: "green",
        fillStyle: "#1ad1b360",
    };
    this.pointStyle = {
        rectWidth: 1,
        strokeStyle: "blue",
    };
    this.highlightStyle = {
        rectWidth: 3,
        strokeStyle: "red",
    };
    console.log("DrawRects initialized");
    console.log(this.canvas);
}

DrawRects.prototype = {
    eachRect(callback) {
        var i = 0;
        while (i < this.items.length) {
            var indices = [i, i + 1, i + 2, i + 3];
            var points = indices.map(i => this.items[i]);
            callback(points, indices);
            i += 4;
        }
    },

    getPointsFromRect(rectIdx) {
        var start = 4 * rectIdx;
        if (this.points.items.length < start + 4) {
            return undefined;
        }
        return [
            this.points.items[start],
            this.points.items[start + 1],
            this.points.items[start + 2],
            this.points.items[start + 3]
        ];
    },

    getRectFromPoint(pointIdx) {
        var rectIdx = (pointIdx / 4 >> 0)
        return this.getPointsFromRect(rectIdx);
    },

    // this will extend the points list
    getClosestPoint(from, minDist) {
        var closestPointP;
        var closestPointIdx;
        this.eachItem((point, i) => {
            const dist = Math.hypot(from.x - point.x, from.y - point.y);
            if (dist <= minDist) {
                closestPointP = point;
                minDist = dist;
                closestPointIdx = i;
            }
        });
        return { p: closestPointP, i: closestPointIdx };
    },

    distanceRectFromPoint(rect, point) {
        var p1 = rect[0];
        var p2 = rect[2];
        var rect_max_x = Math.max(p1.x, p2.x);
        var rect_max_y = Math.max(p1.y, p2.y);
        var rect_min_x = Math.min(p1.x, p2.x);
        var rect_min_y = Math.min(p1.y, p2.y);

        var dx = Math.max(rect_min_x - point.x, 0, point.x - rect_max_x);
        var dy = Math.max(rect_min_y - point.y, 0, point.y - rect_max_y);
        return Math.hypot(dx, dy);
    },

    getClosestRect(that, from, minDist) {
        var closestRectP;
        var closestRectIdx;

        this.eachRect((points, indices) => {
            const dist = that.distanceRectFromPoint(points, from);
            if (dist <= minDist) {
                closestRectP = points;
                minDist = dist;
                closestRectIdx = indices;
            }
        });
        return { p: closestRectP, i: closestRectIdx };
    },

    updateRectCoords(closestPoint) {
        var idx = closestPoint.i;
        var rect = this.getRectFromPoint(idx);
        if (rect === undefined) {
            return;
        }

        idx = idx % 4
        var updateX = (idx + 1) % 4;
        var updateY = (idx + 3) % 4;
        if (idx % 2 === 1) {
            [updateX, updateY] = [updateY, updateX];
        }
        rect[updateX].x = closestPoint.p.x;
        rect[updateY].y = closestPoint.p.y;
    },

    deleteRect(closestRect) {
        if (closestRect.p === undefined) {
            return;
        }
        this.points.del(closestRect.i[0], 4);
        closestRect.p = undefined;
    },

    getCursor(closestPoint, closestRect) {
        cursor = "crosshair";
        if (closestPoint.p) {
            var rect = this.getRectFromPoint(closestPoint.i);
            var idx = (closestPoint.i % 4);
            var idx2 = ((idx + 2) % 4);
            var p = rect[idx];
            var p2 = rect[idx2];

            if ((p.x > p2.x && p.y > p2.y) || (p.x < p2.x && p.y < p2.y)) {
                cursor = "nwse-resize";
            } else {
                cursor = "nesw-resize";
            }
        } else if (closestRect.p) {
            cursor = "move";
        }
        return cursor;
    },

    drawPoint(point) {
        this.ctx.moveTo(point.x, point.y);
        this.ctx.rect(point.x - 2, point.y - 2, 4, 4);
    },

    drawRect(rect) {
        this.ctx.moveTo(rect[0].x, rect[0].y);
        const w = rect[2].x - rect[0].x;
        const h = rect[2].y - rect[0].y;
        this.ctx.fillRect(rect[0].x, rect[0].y, w, h);
    },

    drawRects(that) {
        this.eachRect((rect, i) => that.drawRect(rect))
    },

    drawPoints(that) {
        this.eachItem((point, i) => that.drawPoint(point))
    },

    getMousePos(canvas, evt) {
        var rect = canvas.getBoundingClientRect();
        return {
            x: (evt.clientX - rect.left) / (rect.right - rect.left) * canvas.width,
            y: (evt.clientY - rect.top) / (rect.bottom - rect.top) * canvas.height
        };
    },

    mouseEvents(e) {
        if (e.shiftKey || e.ctrlKey || window.space_pressed) {
            return;  // modifier keys will be used for dragging
        }

        var mouse = this.mouse;
        var mousepos = this.getMousePos(this.canvas, e)
        this.mouse.x = mousepos.x;
        this.mouse.y = mousepos.y;

        const lb = mouse.button;
        mouse.button = e.type === "mousedown" ? true : e.type === "mouseup" ? false : mouse.button;
        if (lb !== mouse.button) {
            if (mouse.button) {
                mouse.drag = true;
                mouse.dragStart = true;
                mouse.dragStartX = mouse.x;
                mouse.dragStartY = mouse.y;
            } else {
                mouse.drag = false;
                mouse.dragEnd = true;
            }
        }
    },

    // main update function
    update(timer) {
        var mouse = this.mouse;
        var points = this.points;
    
        this.globalTime = timer;
        this.ctx.setTransform(1, 0, 0, 1, 0, 0); // reset transform
        this.ctx.globalAlpha = 1;           // reset alpha
        // if (this.w !== innerWidth || this.h !== innerHeight) {
        //     this.cw = (this.w = this.canvas.width = innerWidth) / 2;
        //     this.ch = (this.h = this.canvas.height = innerHeight) / 2;
        // } else {
        //     this.ctx.clearRect(0, 0, this.w, ththisat.h);
        // }
        this.ctx.clearRect(0, 0, this.w, this.h);

        if (mouse.drag === false) {
            this.closestRect.p = undefined;
            this.closestPoint = points.getClosest(mouse, this.minDistPoint);
            if (this.closestPoint.p === undefined) {
                this.closestRect = points.getClosestRect(this, mouse, this.minDistRect);
            }

            this.cursor = this.getCursor(this.closestPoint, this.closestRect);
        }
        if (mouse.dragStart) {
            if (this.closestPoint.p) {
                this.dragOffsetX = this.closestPoint.p.x - mouse.x;
                this.dragOffsetY = this.closestPoint.p.y - mouse.y;
                this.pointDrag = true;

            } else if (this.closestRect.p) {
                this.dragOffsetX = this.closestRect.p[0].x - mouse.x;
                this.dragOffsetY = this.closestRect.p[0].y - mouse.y;
                this.pointDrag = false;

            } else {
                points.add(this.Point2(mouse.x, mouse.y));
                points.add(this.Point2(mouse.x, mouse.y));
                this.closestPoint.p = points.add(this.Point2(mouse.x, mouse.y));
                this.closestPoint.i = points.items.length - 1;
                points.add(this.Point2(mouse.x, mouse.y));
                this.closestRect.p = [
                    points.items[points.items.length - 4],
                    points.items[points.items.length - 3],
                    points.items[points.items.length - 2],
                    points.items[points.items.length - 1],
                ];
                this.dragOffsetX = 0;
                this.dragOffsetY = 0;
                this.pointDrag = true;

            }
            mouse.dragStart = false;

        } else if (mouse.drag) {
            this.cursor = 'none';
            if (this.pointDrag) {
                this.closestPoint.p.x = mouse.x + this.dragOffsetX;
                this.closestPoint.p.y = mouse.y + this.dragOffsetY;
                this.updateRectCoords(this.closestPoint);
            } else {
                const dx = mouse.x - mouse.dragStartX;
                const dy = mouse.y - mouse.dragStartY;
                mouse.dragStartX = mouse.x;
                mouse.dragStartY = mouse.y;
                this.closestRect.i.forEach(i => {
                    points.items[i].x += dx;
                    points.items[i].y += dy;
                });
            }
        } else {
            if (this.delRect) {
                this.deleteRect(this.closestRect);
                this.delRect = false;
            }

        }
        // draw all points and rects
        this.setStyle(this.rectStyle);
        this.ctx.beginPath();
        points.drawRects(this);
        this.ctx.stroke();
        this.setStyle(this.pointStyle);
        this.ctx.beginPath();
        points.draw(this);
        this.ctx.stroke();

        // draw highlighted point or rect
        this.setStyle(this.highlightStyle);
        this.ctx.beginPath();
        if (this.closestRect.p) { this.drawRect(this.closestRect.p) }
        if (this.closestPoint.p) { this.drawPoint(this.closestPoint.p) }

        this.ctx.stroke();

        this.canvas.style.cursor = this.cursor;
        requestAnimationFrame((t)=>this.update(t));  // we need to do this, because otherwise `requestAnimationFrame` will send a different `this` context
    },

    setup() {
        console.log(1);
        ["down", "up", "move"].forEach(name => this.canvas.addEventListener("mouse" + name, (e) => this.mouseEvents(e)));
        this.canvas.addEventListener('keydown', (e) => {
            // console.log(e);
            if (e.key == "Delete" || e.key == "Backspace") {
                this.delRect = true;
            }
        });

        this.canvas.style.left = window.getComputedStyle(this.img).left;
        this.canvas.style.top = window.getComputedStyle(this.img).top;
        this.canvas.style.width = window.getComputedStyle(this.img).width;
        this.canvas.style.height = window.getComputedStyle(this.img).height;
        this.canvas.style.visibility = "visible";

        requestAnimationFrame((t)=>this.update(t));  // we need to do this, because otherwise `requestAnimationFrame` will send a different `this` context

    }
}

// todo: if mouse position outside of canvas, then drag should stop
