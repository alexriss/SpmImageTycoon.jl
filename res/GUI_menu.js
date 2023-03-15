function setup_menu() {
    setup_menu_main();
    setup_menu_sidebar();
}

function setup_menu_main() {
    // create main icons in navbar

    const container = document.getElementById("menu_main");
    const tpl = document.getElementById("template_icon_menu");

    console.log(1);
    Object.entries(icon_menu).forEach(([key, value]) => {
        const clone = tpl.content.cloneNode(true);
        clone.firstElementChild.id = "menu_icon_menu_" + key;
        const img = clone.querySelector(".icon img");
        img.src = value.icon;
        const title = clone.querySelector(".icon_menu_title");
        title.innerHTML = value.title;

        if ("info_disabled" in value) {
            const info = clone.querySelector(".icon_menu_info_disabled");
            info.innerHTML = value.info_disabled;
        }
        clone.firstElementChild.addEventListener("click", () => {
            value.command(...value.args);
        });
        container.appendChild(clone);
    });
}


function setup_menu_sidebar() {
    // create sidebar icons in navbar

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