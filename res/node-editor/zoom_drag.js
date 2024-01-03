function ZoomDragNodeEditor(divMain, subElementSelector) {
    const that = this;
    
    // config
    this.scale = 1;  // initial scale
    this.factor = 0.1;
    this.maxScale = 3;
    this.minScale = 0.2;
    
    this.divMain = divMain;

    this.setZoom(this.scale);
    this.setScroll({x: 0, y: 0}); 

    this.moveEnabled = false;  // set from outside

    this.subElementSelector = subElementSelector;  


    // dragging

    // when mouse is pressed store the current mouse x,y
    let previousX, previousY;
    divMain.addEventListener('mousedown', (e) => {
        previousX = e.pageX;
        previousY = e.pageY;
    })

    // when mouse is moved, scrollBy() the mouse movement x,y
    divMain.addEventListener('mousemove', (e) => {
        // only do this when the primary mouse button is pressed (e.buttons = 1)
        if (e.buttons) {
            let dragX = 0;
            let dragY = 0;
            // skip the drag when the x position was not changed
            if (e.pageX - previousX !== 0) {
                dragX = previousX - e.pageX;
                previousX = e.pageX;
            }
            // skip the drag when the y position was not changed
            if (e.pageY - previousY !== 0) {
                dragY = previousY - e.pageY;
                previousY = e.pageY;
            }

            if (!that.getMoveEnabled(e)) {
                return;
            }

            // scrollBy x and y
            if (dragX !== 0 || dragY !== 0) {
                divMain.scrollBy(dragX, dragY);
            }       
        }

    });

    // zoom in/out on the section
    divMain.addEventListener('wheel', (e) => {
        e.preventDefault();

        let delta = e.delta || e.wheelDelta;
        if (delta === undefined) {
            //we are on firefox
            delta = e.originale.detail;
        };
        delta = Math.max(-1, Math.min(1, delta)); // cap the delta to [-1,1] for cross browser consistency

        // calculate new zoom
        let scale = that.scale + delta * that.factor * that.scale;
        scale = Math.max(that.minScale, Math.min(that.maxScale, scale));
  
        for (const divSection of divMain.getElementsByTagName('section')) {
            const displayWidth = divSection.clientWidth * scale;
            const displayHeight = divSection.clientHeight * scale;
            if (divMain.clientHeight > displayHeight) {
                divMain.scrollTop = 0;
                return;
            }
            else if (divMain.clientWidth > displayWidth) {
                divMain.scrollLeft = 0;
                return;
            }
        }
        const newScroll = that.getNewScrollEvent(e, that.scale, scale);
        that.setZoom(scale);
        that.setScroll(newScroll);
    });

    // reset on doubleclick
    divMain.addEventListener('dblclick', (e) => {
        if (e.ctrlKey || e.metaKey || e.altKey || e.shiftKey) {
            this.resetZoom(e);
        } else {
            this.adjustView();
        }
    });
}

ZoomDragNodeEditor.prototype = {
    resetZoom(e) {
        const newScroll = this.getNewScrollEvent(e, this.scale, 1);
        this.setZoom(1);
        this.setScroll(newScroll);
    },

    adjustView() {
        // adjust zoom and scroll so that all elements are visible
        let scale = 1;
        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        for (const divSection of this.divMain.getElementsByTagName('section')) {
            for (const divElement of divSection.querySelectorAll(this.subElementSelector)) {
                const rect = divElement.getBoundingClientRect();
                minX = Math.min(minX, rect.left);
                minY = Math.min(minY, rect.top);
                maxX = Math.max(maxX, rect.right);
                maxY = Math.max(maxY, rect.bottom);
            }
            const NodesWidth = (maxX - minX) / this.scale;
            const NodesHeight = (maxY - minY) / this.scale;
            const mainWidth = this.divMain.getBoundingClientRect().width;
            const mainHeight = this.divMain.getBoundingClientRect().height;

            const scaleX = mainWidth / NodesWidth;
            const scaleY = mainHeight / NodesHeight;

            scale = Math.min(scale, Math.min(scaleX, scaleY));
        }

        // scale = scale * this.scale;
        scale *= 0.9;
        scale = Math.max(this.minScale, Math.min(1, scale));
        const center = {
            x: (minX + maxX) / 2,
            y: (minY + maxY) / 2 
        };
        const rectMain = this.divMain.getBoundingClientRect();
        const centerView = {
            x: rectMain.width / 2 + rectMain.left,
            y: rectMain.height / 2 + rectMain.top
        };
        const newScroll = this.getNewScroll(center, centerView, this.scale, scale);

        this.setZoom(scale);
        this.setScroll(newScroll);

    },

    setZoom(scale) {
        for (const divSection of this.divMain.getElementsByTagName('section')) {
            divSection.style.transform = `scale(${scale}, ${scale})`;
        }
        this.scale = scale;
    },

    getNewScrollEvent(e, scaleOld, scaleNew) {
        const pos = {x: e.clientX, y: e.clientY};
        return this.getNewScroll(pos, pos, scaleOld, scaleNew);
    },

    getNewScroll(pos, posView, scaleOld, scaleNew) {
        const offset = { x: this.divMain.scrollLeft, y: this.divMain.scrollTop };
        const rect = this.divMain.getBoundingClientRect();
        const imageLoc = {
            x: pos.x - rect.left + offset.x,
            y: pos.y - rect.top + offset.y
        };

        const zoomPoint = {
            x: imageLoc.x / scaleOld * scaleNew,
            y: imageLoc.y / scaleOld * scaleNew
        };

        const newScroll = {
            x: zoomPoint.x - (posView.x - rect.left),
            y: zoomPoint.y - (posView.y - rect.top)
        };
        return newScroll
    },

    setScroll(scroll) {
        this.divMain.scrollTop = scroll.y;
        this.divMain.scrollLeft = scroll.x;
    },

    getMoveEnabled() {
        return this.moveEnabled;
    },

    setMoveEnabled(moveEnabled) {
        this.moveEnabled = moveEnabled;
    }
}
