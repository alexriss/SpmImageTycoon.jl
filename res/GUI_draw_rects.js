const { cp } = require("fs");

function DrawRects(canvas_element, img_element, lambdaX_element, lambdaY_element, lambdaA_element) {
    var self = this;
    this.first_setup = false;

    this.canvas = canvas_element;
    this.img = img_element;
    this.ctx = this.canvas.getContext("2d");
    this.lambdaX = lambdaX_element;
    this.lambdaY = lambdaY_element;
    this.lambdaA = lambdaA_element;
    
    this.callback = null;  // callback function when changes occur

    this.imgPixelsize = [0, 0]  // needed for conversions etc
    this.scansize = [0, 0]  // needed for conversions etc
    this.maxFreq = [0., 0.]  // needed for conversions etc

    this.unit_prefix = "";  // prefix for unit (i.e. m, µ, p, f, ...)
    this.unit_exponent = 0;  // exponent for the unit

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
    this.maxSideLength = 1000; // resolution of the canvas
    this.exportScale = 1e6; // max scale to export point coordinates
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

    this.col1 = "#4288c2";
    this.col2 = "#bf365a";
    this.setColors("p");
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

    savePoints() {
        // saves points to array (compressed, i.e. only point 1 and 3 of every rect)
        // normalizes the coordinates to [0, 1]
        // also converts array of objects to array of arrays
        var points = [...this.points.items]; // create copy to minimize race conditions
        const scaleX = this.exportScale / this.canvas.width;
        const scaleY = this.exportScale / this.canvas.height;
        var pointsCompressed = [];
        var x, y;
        for (var i = 0; i < points.length; i += 4) {
            x = Math.round(points[i].x * scaleX);
            y = Math.round(points[i].y * scaleY);
            pointsCompressed.push([x, y]);
            x = Math.round(points[i + 2].x * scaleX);
            y = Math.round(points[i + 2].y * scaleY);
            pointsCompressed.push([x, y]);
        }
        return pointsCompressed;
    },

    loadPoints(points) {
        // loads points from array (compressed, i.e. only point 1 and 3 of every rect)
        // changes scale according to this.exportScale
        // also converts array of arrays to array of objects
        const scaleX = this.canvas.width / this.exportScale;
        const scaleY = this.canvas.height / this.exportScale;
        
        var pointsExpanded = [];
        for (var i = 0; i < points.length; i += 2) {
            pointsExpanded.push({x: points[i][0] * scaleX, y: points[i][1] * scaleY});
            pointsExpanded.push({x: points[i][0] * scaleX, y: points[i + 1][1] * scaleY});
            pointsExpanded.push({x: points[i + 1][0] * scaleX, y: points[i + 1][1] * scaleY});
            pointsExpanded.push({x: points[i + 1][0] * scaleX, y: points[i][1] * scaleY});
        }
        this.points.items = pointsExpanded;
    },

    clearAll() {
        this.points.items = [];
        if (this.callback !== null) this.callback();
    },

    setColors(type) {
        var col1 = this.col1;
        var col2 = this.col2;
        if (type === "r") { // remove-type
            col1 = this.col2;
            col2 = this.col1;
        }
        this.rectStyle = {
            lineWidth: 3,
            strokeStyle: col1,
            fillStyle: col1 + "90",
        };
        this.pointStyle = {
            lineWidth: 1,
            fillStyle: col1,
        };
        this.highlightRectStyle = {
            lineWidth: 5,
            fillStyle: col1 + "90",
            strokeStyle: col2,
        }
        this.highlightPointStyle = {
            lineWidth: 5,
            strokeStyle: col2,
        }
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
        this.ctx.fillRect(point.x, point.y, 1, 1);
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

    displayLambda(mousepos) {
        if (this.scansize[0] === 0 || this.scansize[1] === 0 ||
            this.imgPixelsize[0] === 0 || this.imgPixelsize[1] === 0 ||
            this.canvas.width === 0 || this.canvas.height === 0) {
            return;
        }
        
        const xRel = (mousepos.x / this.canvas.width - 0.5) * 2;  // goes from -1 to 1
        const yRel = mousepos.y / this.canvas.height; // goes from 0 to 1

        const maxFreqX = this.maxFreq[0] / this.scansize[0] * this.imgPixelsize[0];  // max freq is ~0.5 / pixel
        const maxFreqY = this.maxFreq[1] / this.scansize[1] * this.imgPixelsize[1];  // max freq is ~0.5 / pixel
        const freqX = maxFreqX * xRel;
        const freqY = maxFreqY * yRel;
        let resX = "";
        if (Math.abs(freqX) < 1e-6) {
            resX = "&infin;";
        } else {
            resX = (1 / freqX).toFixed(3);
        }
        let resY = "";
        if (freqY < 1e-6) {
            resY = "&infin;";
        } else {
            resY = (1 / freqY).toFixed(3);
        }
        let resA = "";
        if (Math.abs(freqX) < 1e-6 || freqY < 1e-6) {
            resA = "&infin;";
        } else {
            resA = (1 / Math.sqrt(freqX**2 + freqY**2)).toFixed(3);
        }
        this.lambdaX.innerHTML = resX;
        this.lambdaY.innerHTML = resY;
        this.lambdaA.innerHTML = resA;
    },

    mouseEvents(e) {
        if (e.shiftKey || e.ctrlKey || window.space_pressed) {
            return;  // modifier keys will be used for dragging
        }

        var mouse = this.mouse;
        var mousepos = this.getMousePos(this.canvas, e)
        this.mouse.x = mousepos.x;
        this.mouse.y = mousepos.y;

        this.displayLambda(mousepos);

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
        
        const outside = e.type === "mouseout";
        if (outside) {
            mouse.drag = false;
            mouse.dragEnd = true;
            mouse.button = false;
        }
        if (e.type === "mouseup" || outside) {
            if (this.callback !== null) this.callback();
        }
        if (e.type === "mouseout") {
            this.lambdaX.parentElement.classList.add("is-invisible");
        } else {
            this.lambdaX.parentElement.classList.remove("is-invisible");
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
        if (this.closestRect.p) {
            this.setStyle(this.highlightRectStyle);
            this.ctx.beginPath();
            this.drawRect(this.closestRect.p);
        }
        if (this.closestPoint.p) {
            this.setStyle(this.highlightPointStyle);
            this.ctx.beginPath();
            this.drawPoint(this.closestPoint.p);
        }

        this.ctx.stroke();

        this.canvas.style.cursor = this.cursor;
        requestAnimationFrame((t)=>this.update(t));  // we need to do this, because otherwise `requestAnimationFrame` will send a different `this` context
    },

    setup(callback=null, scansize=[0,0], imgPixelsize=[0,0], maxFreq=[0,0]) {
        ["down", "up", "move", "out"].forEach(name => this.canvas.addEventListener("mouse" + name, (e) => this.mouseEvents(e)));
        this.canvas.addEventListener('keydown', (e) => {
            if (e.key == "Delete" || e.key == "Backspace") {
                this.delRect = true;
            }
        });
        this.scansize = scansize;
        this.imgPixelsize = imgPixelsize;
        this.maxFreq = maxFreq;
        this.setupImage();
        this.callback = callback;
        requestAnimationFrame((t)=>this.update(t));  // we need to do this, because otherwise `requestAnimationFrame` will send a different `this` context
    },

    setupImage() {
        if (this.first_setup) {
            return;
        }
        let w = this.img.naturalWidth;
        let h = this.img.naturalHeight;
        if (w === 0 || h === 0) {
            window.setTimeout(() => this.setupImage(), 100);    // wait for image to load
        }

        let maxSideLength = Math.max(this.maxSideLength, Math.max(w, h));
        if (w >= h) {
            this.canvas.width = maxSideLength;
            this.canvas.height = maxSideLength * h/w;
            this.img.classList.remove("fullheight");
            this.img.classList.add("fullwidth");
            this.img.style.height = "auto";
            this.canvas.classList.remove("fullheight");
            this.canvas.classList.add("fullwidth");
            this.canvas.style.height = "auto";

        } else {
            this.canvas.height = maxSideLength;
            this.canvas.width = maxSideLength * w/h;
            this.img.classList.remove("fullwidth");
            this.img.classList.add("fullheight");
            this.img.style.height = this.img.parentElement.clientWidth * Math.min(h/w, 1.1) + "px";
            this.canvas.classList.remove("fullwidth");
            this.canvas.classList.add("fullheight");
            this.canvas.style.height = this.img.style.height;
        }
        this.w = this.canvas.width;
        this.h = this.canvas.height;
        this.cw = this.w / 2;  // center
        this.ch = this.h / 2;

        // this.canvas.style.left = window.getComputedStyle(this.img).left;
        // this.canvas.style.top = window.getComputedStyle(this.img).top;
        // this.canvas.style.width = window.getComputedStyle(this.img).width;
        // this.canvas.style.height = window.getComputedStyle(this.img).height;
        // this.canvas.style.visibility = "visible";
        this.canvas.classList.remove("is-invisible");
        this.img.classList.remove("is-invisible");
        this.first_setup = true;
    }
}
