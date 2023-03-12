function setup_menu() {
    setup_menu_sidebar();
}

function setup_menu_sidebar() {
    const container = document.getElementById("menu_sidebar");
    const tpl = document.getElementById("template_icon_sidebar");

    Object.entries(icon_sidebar).forEach(([key, value]) => {
        const clone = tpl.content.cloneNode(true);
        clone.firstElementChild.id = "menu_icon_sidebar_" + key;
        const img = clone.querySelector(".icon img");
        img.src = value.icon;
        const title = clone.querySelector(".icon_sidebar_title");
        title.innerHTML = value.title;

        if ("info_disabled" in value) {
            const info = clone.querySelector(".icon_sidebar_info_disabled");
            info.innerHTML = value.info_disabled;
        }
        clone.firstElementChild.addEventListener("click", () => {
            value.command(...value.args);
        });
        container.appendChild(clone);
    });
}