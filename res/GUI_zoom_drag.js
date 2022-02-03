// for imagezoom

function zoom_drag_setup(divMain) {

    // config
    let scale = 1;  // initial scale
    const factor = 0.2;
    const max_scale = 10;
    const min_scale = 0.1;

    window.scale = scale;  // need a global variable here

    // drag the section
    for (const divSection of divMain.getElementsByTagName('section')) {
        // when mouse is pressed store the current mouse x,y
        let previousX, previousY;
        divSection.addEventListener('mousedown', (event) => {
            if (window.sidebar_imagezoomtools && !document.getElementById("line_profile").classList.contains("is-hidden")) {
                if (!event.shiftKey && !event.ctrlKey && !event.altKey && !window.space_pressed) {  // dragging only with modifier - line profile dragging has priority
                    return;
                }
            }
            previousX = event.pageX;
            previousY = event.pageY;
        })

        // when mouse is moved, scrollBy() the mouse movement x,y
        divSection.addEventListener('mousemove', (event) => {
            // only do this when the primary mouse button is pressed (event.buttons = 1)
            if (event.buttons) {
                if (window.sidebar_imagezoomtools && !document.getElementById("line_profile").classList.contains("is-hidden")) {
                    if (!event.shiftKey && !event.ctrlKey && !event.altKey && !window.space_pressed) {  // dragging only with modifier - line profile dragging has priority
                        return;
                    }
                }

                let dragX = 0;
                let dragY = 0;
                // skip the drag when the x position was not changed
                if (event.pageX - previousX !== 0) {
                    dragX = previousX - event.pageX;
                    previousX = event.pageX;
                }
                // skip the drag when the y position was not changed
                if (event.pageY - previousY !== 0) {
                    dragY = previousY - event.pageY;
                    previousY = event.pageY;
                }
                // scrollBy x and y
                if (dragX !== 0 || dragY !== 0) {
                    divMain.scrollBy(dragX, dragY);
                }
            }
        })
    }

    // zoom in/out on the section
    divMain.addEventListener('wheel', (e) => {
        // preventDefault to stop the onselectionstart event logic
        for (const divSection of divMain.getElementsByTagName('section')) {
            e.preventDefault();
            var delta = e.delta || e.wheelDelta;
            if (delta === undefined) {
                //we are on firefox
                delta = e.originalEvent.detail;
            };
            delta = Math.max(-1, Math.min(1, delta)); // cap the delta to [-1,1] for cross browser consistency
            offset = { x: divMain.scrollLeft, y: divMain.scrollTop };

            const rect = divMain.getBoundingClientRect();
            image_loc = {
                x: e.clientX - rect.left + offset.x,
                y: e.clientY - rect.top + offset.y
            };

            zoom_point = { x: image_loc.x / window.scale, y: image_loc.y / window.scale };

            // apply zoom
            window.scale += delta * factor * window.scale;
            window.scale = Math.max(min_scale, Math.min(max_scale, window.scale));

            if (window.scale < 1) {
                divSection.style.transformOrigin = "center";
            } else {
                divSection.style.transformOrigin = "0 0";
            }

            zoom_point_new = { x: zoom_point.x * window.scale, y: zoom_point.y * window.scale };

            newScroll = {
                x: zoom_point_new.x - (e.clientX - rect.left),
                y: zoom_point_new.y - (e.clientY - rect.top)
            };

            divSection.style.transform = `scale(${window.scale}, ${window.scale})`;
            divMain.scrollTop = newScroll.y;
            divMain.scrollLeft = newScroll.x;
        }
    })

    // reset on doubleclick
    divMain.addEventListener('dblclick', (e) => {
        if (window.sidebar_imagezoomtools && !document.getElementById("line_profile").classList.contains("is-hidden")) {
            if (!e.shiftKey && !e.ctrlKey && !e.altKey && !window.space_pressed) {  // dragging only with modifier - line profile dragging has priority
                return;
            }
        }
        if (!e.ctrlKey) {
            zoom_drag_reset(divMain);
        }
    })
}

function zoom_drag_reset(divMain) {
    window.scale = 1
    for (const divSection of divMain.getElementsByTagName('section')) {
        divSection.style.transform = "scale(1, 1)";
    }
    divMain.scrollTop = 0;
    divMain.scrollLeft = 0;
}



// for filter overview
// here we will use percentages instead of transform: scale
// otherwise the borders get really thick
function zoom_drag_filter_overview_setup(divMain) {

    // config
    let scale = 1.;  // initial scale
    const factor = 0.2;
    const max_scale = 800.0;
    const min_scale = 1.;

    window.scale_filter_overview = scale  // need a global variable here

    // drag the section
    for (const divSection of divMain.getElementsByTagName('section')) {
        // when mouse is pressed store the current mouse x,y
        let previousX, previousY;
        divSection.addEventListener('mousedown', (event) => {
            if (window.filter_overview_selecting) {
                if (!event.altKey && !window.space_pressed) {  // dragging only with modifier - line profile dragging has priority
                    return;
                }
            }
            previousX = event.pageX;
            previousY = event.pageY;
        })

        // when mouse is moved, scrollBy() the mouse movement x,y
        divSection.addEventListener('mousemove', (event) => {
            // only do this when the primary mouse button is pressed (event.buttons = 1)
            if (event.buttons) {
                if (window.filter_overview_selecting) {
                    if (!event.altKey && !window.space_pressed) {  // dragging only with modifier - line profile dragging has priority
                        return;
                    }
                }
    
                let dragX = 0;
                let dragY = 0;
                // skip the drag when the x position was not changed
                if (event.pageX - previousX !== 0) {
                    dragX = previousX - event.pageX;
                    previousX = event.pageX;
                }
                // skip the drag when the y position was not changed
                if (event.pageY - previousY !== 0) {
                    dragY = previousY - event.pageY;
                    previousY = event.pageY;
                }
                // scrollBy x and y
                if (dragX !== 0 || dragY !== 0) {
                    divMain.scrollBy(dragX, dragY);
                }
            }
        })
    }

    // zoom in/out on the section
    divMain.addEventListener('wheel', (e) => {
        // preventDefault to stop the onselectionstart event logic
        for (const divSection of divMain.getElementsByTagName('section')) {
            e.preventDefault();
            var delta = e.delta || e.wheelDelta;
            if (delta === undefined) {
                //we are on firefox
                delta = e.originalEvent.detail;
            }
            delta = Math.max(-1, Math.min(1, delta)); // cap the delta to [-1,1] for cross browser consistency
            offset = { x: divMain.scrollLeft, y: divMain.scrollTop };

            const rect = divMain.getBoundingClientRect();
            image_loc = {
                x: e.clientX - rect.left + offset.x,
                y: e.clientY - rect.top + offset.y
            };

            zoom_point = { x: image_loc.x / window.scale_filter_overview, y: image_loc.y / window.scale_filter_overview };

            // apply zoom
            window.scale_filter_overview += delta * factor * window.scale_filter_overview;
            window.scale_filter_overview = Math.max(min_scale, Math.min(max_scale, window.scale_filter_overview));

            if (window.scale_filter_overview < 1) {
                divSection.style.transformOrigin = "center";
            } else {
                divSection.style.transformOrigin = "0 0";
            }

            zoom_point_new = { x: zoom_point.x * window.scale_filter_overview, y: zoom_point.y * window.scale_filter_overview };

            newScroll = {
                x: zoom_point_new.x - (e.clientX - rect.left),
                y: zoom_point_new.y - (e.clientY - rect.top)
            };

            // divSection.style.transform = `scale(${window.scale_filter_overview}, ${window.scale_filter_overview})`
            divSection.style.width = `${100*window.scale_filter_overview}%`;
            divSection.style.height = `${100*window.scale_filter_overview}%`;
    
            divMain.scrollTop = newScroll.y;
            divMain.scrollLeft = newScroll.x;
            filter_overview_display_coordinates(e);
            if (window.scale_filter_overview == 1) {
                document.getElementById("filter_overview_reset_zoom").classList.add("is-hidden");
            } else {
                document.getElementById("filter_overview_reset_zoom").classList.remove("is-hidden");
            }
        }
    })

    // reset on doubleclick
    divMain.addEventListener('dblclick', (e) => {
        if (window.filter_overview_selecting) {
            if (!e.altKey && !window.space_pressed) {  // dragging only with modifier - line profile dragging has priority
                return;
            }
        }
        if (!e.ctrlKey) {
            zoom_drag_filter_overview_reset(divMain);
            filter_overview_display_coordinates(e);
        }
    })
}

function zoom_drag_filter_overview_reset(divMain) {
    window.scale_filter_overview = 1
    for (const divSection of divMain.getElementsByTagName('section')) {
        divSection.style.width = "100%";
        divSection.style.height = "100%";
    }

    divMain.scrollTop = 0;
    divMain.scrollLeft = 0;

    document.getElementById("filter_overview_reset_zoom").classList.add("is-hidden");
}
