function filter_overview_rel_to_nm(xy_rel) {
    // converts relative coordinates to physical coordinates
    const scanrange_full = [
        window.topright[0] - window.bottomleft[0],
        window.topright[1] - window.bottomleft[1]
    ];
    const xy_nm = [
        xy_rel[0] * scanrange_full[0] + window.bottomleft[0],
        (1 - xy_rel[1]) * scanrange_full[1] + window.bottomleft[1]  // y in physical units goes from bottom to top
    ];
    return xy_nm;
}

function filter_overview_nm_to_rel(xy_nm, coords=true) {
    // converts physical coordinates to pixel coordinates
    // if coords is false, then a span is assumed (x and y behave similarly)
    var xy_rel = [0.0, 0.0];
    if (coords) {
        xy_rel = [
            (xy_nm[0] - window.bottomleft[0]) / (window.topright[0] - window.bottomleft[0]),
            1 - (xy_nm[1] - window.bottomleft[1]) / (window.topright[1] - window.bottomleft[1])  // y in physical units goes from bottom to top
        ];
    } else {
        xy_rel = [
            xy_nm[0] / (window.topright[0] - window.bottomleft[0]),
            xy_nm[1] / (window.topright[1] - window.bottomleft[1])
        ];
    }
    return xy_rel;
}

function filter_overview_display_coordinates(e) {
    // displays coordinates when mouse moves across the overview

    // get coordinates, similar to GUI_line_profile.js
    const rect = document.getElementById("filter_overview").getBoundingClientRect();
    const xy_rel = [
        (e.clientX - rect.left) / (rect.right - rect.left),
        (e.clientY - rect.top) / (rect.bottom - rect.top)
    ];

    const xy_nm = filter_overview_rel_to_nm(xy_rel);

    document.getElementById("filter_overview_position_x").innerText = xy_nm[0].toFixed(1);
    document.getElementById("filter_overview_position_y").innerText = xy_nm[1].toFixed(1);
}