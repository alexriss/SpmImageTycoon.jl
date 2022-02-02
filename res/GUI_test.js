
function test_press_key(k, modifiers, el=document) {
    // simulates keypress (for testing purposes)
    let props = { key: k };

    if (modifiers.includes("shift")) {
        props["shiftKey"] = true;
    }
    if (modifiers.includes("ctrl")) {
        props["ctrlKey"] = true;
    }
    if (modifiers.includes("alt")) {
        props["altKey"] = true;
    }

    el.dispatchEvent(new KeyboardEvent('keydown', props));
}

function test_click_mouse(selector) {
    // clicks mouse on all elements selected by selector (for testing purposes)
    document.querySelectorAll(selector).forEach(el => {
        el.click();
    });
}