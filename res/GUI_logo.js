
window.interval_logo = null;  // holds interval for logo spinning

function start_page_logo_spin(start=true) {
    if (!start) {
        if (window.interval_logo !== null) {
            window.clearInterval(window.interval_logo);
            window.interval_logo = null;
        }
        return;
    }

    window.interval_logo = window.setInterval(function() {
        let css_classes = ["rotated", "rotated2", "rotated3", "rotated4", "rotated5", "rotated6"];
        let els = document.getElementById("logo_animation").getElementsByClassName("box_animation");
        for (let i=0;i<els.length;i++) {
            let removed = false;
            let el = els[i];
            for (let j=0;j<css_classes.length;j++) {
                if (el.classList.contains(css_classes[j])) {
                    el.classList.remove(css_classes[j]);
                    removed = true;
                }
            }
            if (!removed) {
                let css_class = css_classes[Math.floor(Math.random() * css_classes.length)];
                el.classList.add(css_class);
            }
        }
    }, 6000);
}