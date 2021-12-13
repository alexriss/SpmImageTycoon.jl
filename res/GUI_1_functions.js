// general functions

function format_number_prefix(number, decimals=2) {
    // rounds anumber and also formats using the prefix;
    // returns and object: scaled number (float), formatted number (string), prefix (string)
    
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
    
    return {number_scaled: n , number_formatted: n.toFixed(decimals), prefix: unit_prefix};
}

