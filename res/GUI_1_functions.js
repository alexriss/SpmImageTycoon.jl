// general functions

function format_number_prefix(number, decimals=2) {
    // rounds a number and also formats using the prefix;
    // returns an object: scaled number (float), formatted number (string), prefix (string)

    if (number === null) {// Julia NaNs get sent as null-values
        return {number_scaled: NaN , number_formatted: "-", prefix: "", exponent: 0};
    }
    
    const unit_prefixes = ["E", "P", "T", "G", "M", "k", "", "m", "u", "n", "p", "f", "a"];
    const unit_exponents = [18, 15, 12, 9, 6, 3, 0, -3, -6, -9, -12, -15, -18];
    let unit_prefix = "";
    let unit_exponent = 0;
    let n = Math.abs(number)

    if (n == 0) {
        unit_prefix = "";
        unit_exponent = 0;
    } else {
        for (let i=0; i<unit_exponents.length;i++) {
            if (n > 10**unit_exponents[i] * 0.099999) {
                unit_exponent = unit_exponents[i];
                unit_prefix = unit_prefixes[i];
                break;
            }
        }
    }

    n = number / 10**unit_exponent;
    
    return {number_scaled: n , number_formatted: n.toFixed(decimals), prefix: unit_prefix, exponent: unit_exponent};
}


function format_numbers_prefix(numbers, decimals=2) {
    // rounds multiple number and also formats using the prefix;
    // returns an array of objects: scaled number (float), formatted number (string), prefix (string)

    let max_abs_value = 0;
    for (let i=0; i<numbers.length; i++) {
        abs_value = Math.abs(numbers[i]);
        if (abs_value > max_abs_value) {
            max_abs_value = abs_value;
        }
    }

    const fnpe = format_number_prefix(max_abs_value, decimals);
    const result = numbers.map(function(number) {
        n = number / 10**fnpe.exponent;
        return {number_scaled: n, number_formatted: n.toFixed(decimals), prefix: fnpe.prefix, exponent: fnpe.exponent};
    })

    return result;
}


// for dragging input type fields
function getFloatCtrl(el) { return(parseFloat(el.value)); }

function input_number_dragable(el) {
    var startpos;
    var startval;
    el.onmousedown = function(e) {
        startpos = e.clientX;
        startval = getFloatCtrl(el);
        if (isNaN(startval)) startval = 0;

        document.onmousemove = function(e) {
            var delta = Math.ceil(e.clientX - startpos);      
            scaledIntCtrl(el, startval, delta);
        };

        document.onmouseup = function() {
            document.onmousemove = null; // remove mousemove to stop tracking
        };
    };
}

// takes current value and relative mouse coordinate as arguments
function scaledIntCtrl(o, i, x) {
    let incScale = 1.0;
    if ("dragstep" in o.dataset) {
        incScale = parseFloat(o.dataset.dragstep);
    } else if (o.hasAttribute("step")) {
        incScale = parseFloat(o.getAttribute("step"));
    }

    const incVal = Math.round(Math.sign(x) * Math.pow(Math.abs(x)/10, 1.6));
    const newVal = i + incVal * incScale;

    if (("min" in o.dataset) && newVal < parseFloat(o.dataset.min)) return;
    if (("max" in o.dataset) && newVal > parseFloat(o.dataset.max)) return;
    // if (Math.abs(incVal)>1) o.value = newVal; // allow small deadzone
    o.value = newVal; // allow small deadzone

    // trigger change event
    var event = new Event('change');
    o.dispatchEvent(event);
}

function input_number_dragable_all() {
    document.querySelectorAll('input[type=number][data-drag="1"]').forEach((el) => {
        input_number_dragable(el);
    });
}
