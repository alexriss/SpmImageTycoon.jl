function SpectrumPlot(container_element) {
    this.container = container_element;
    this.plot_object = null;  // holds the plot object
    this.first_setup = false;

    this.unit_prefix = "";  // prefix for unit (i.e. m, µ, p, f, ...)
    this.unit_exponent = 0;  // exonent for the unit
    this.unit2_prefix = "";  // prefix for unit (i.e. m, µ, p, f, ...)
    this.unit2_exponent = 0;  // exonent for the unit

    // used for inversion in x and y
    this.x_factor = 1.;
    this.y_factor = 1.;

    this.ySeries = {
        show: true,
        spanGaps: true,
        label: "",
        value: (self, rawValue) => this.formatValue(rawValue, this.unit_exponent, 3, this.y_factor),
        stroke: "#3676d7",
        width: 1,
    },
    this.ySeries_scatter = {
        show: true,
        spanGaps: false,
        label: "",
        value: (self, rawValue) => this.formatValue(rawValue, this.unit_exponent, 3,  this.y_factor),
        stroke: "#3676d7",
        paths: u => null,
        points: {
            space: 0,
            fill: "#3676d7",
        },
        width: 1,

    }
    this.xSeries = {
        show: true,
        spanGaps: true,
        label: "",
        value: (self, rawValue) => this.formatValue(rawValue, this.unit2_exponent, 3,  this.x_factor),
        stroke: "#3676d7",
        width: 1,
    }
}

SpectrumPlot.prototype = {
    // formats value (using the right exponent)
    formatValue(val, unit_exponent, decimals=2, factor=1.) {
        if (isNaN(val)) {
            return "--";
        }
        return (val / 10**unit_exponent * factor).toFixed(decimals);
    },

    // get size of container
    getSize() {
        return {
            width: this.container.parentElement.clientWidth - 20,
            height: this.container.parentElement.clientHeight - 60
        }
    },

    getLabel(suffix = "") {
        const griditem = window.items[window.zoom_last_selected];
        return griditem.channel_name + " " + suffix + " [" + this.unit_prefix +  griditem.channel_unit + "]"
    },

    getLabel2(suffix = "") {
        const griditem = window.items[window.zoom_last_selected];
        return griditem.channel2_name + " " + suffix + " [" + this.unit2_prefix +  griditem.channel2_unit + "]"
    },

    // plot the line profile
    plotSpectrum(spectrum_data) {
        if (this.plot_object !== null) {
            const griditem = window.items[window.zoom_last_selected];

            // set x and y prefixes and exponents
            let nfpe = format_numbers_prefix([griditem.channel_range[0], griditem.channel_range[1]]);
            this.unit_prefix = nfpe[0].prefix;
            this.unit_exponent = nfpe[0].exponent;
            nfpe = format_numbers_prefix([griditem.channel_range[2], griditem.channel_range[3]]);
            this.unit2_prefix = nfpe[0].prefix;
            this.unit2_exponent = nfpe[0].exponent;

            this.x_factor = (spectrum_data["x_inverted"]) ? -1. : 1.;
            this.y_factor = (spectrum_data["y_inverted"]) ? -1. : 1.;
    
            const x_data = spectrum_data["x_data"];
            const y_datas = spectrum_data["y_datas"];
            const colors = spectrum_data["colors"];

            while (this.plot_object.series.length > 0) {
                this.plot_object.delSeries(this.plot_object.series.length - 1);
            }
            let xSeries = this.xSeries;
            xSeries.label = this.getLabel2()
            this.plot_object.addSeries(this.xSeries, 0);
            let ySeries, suffix;
            for (let i=0; i<y_datas.length; i++) {
                if (spectrum_data["type"] == "line") {
                    ySeries = this.ySeries;
                } else {
                    ySeries = this.ySeries_scatter;
                    ySeries.points.fill = colors[i];
                }
    
                suffix = (i == 1) ? "bwd" : "";
                ySeries.label = this.getLabel(suffix);
                ySeries.stroke = colors[i];
                this.plot_object.addSeries(ySeries, i+1);
            }

            this.plot_object.setData([x_data, ...y_datas], false);  // last parameter is resetScales, can be false here
            
            let channel_range_selected = griditem.channel_range_selected;
            if (channel_range_selected.length != 4) {
                channel_range_selected = [0., 1., 0., 1.];
            }
            const y_min = griditem.channel_range[0] + (griditem.channel_range[1] - griditem.channel_range[0]) * griditem.channel_range_selected[0];
            const y_max = griditem.channel_range[0] + (griditem.channel_range[1] - griditem.channel_range[0]) * griditem.channel_range_selected[1];
            const x_min = griditem.channel_range[2] + (griditem.channel_range[3] - griditem.channel_range[2]) * griditem.channel_range_selected[2];
            const x_max = griditem.channel_range[2] + (griditem.channel_range[3] - griditem.channel_range[2]) * griditem.channel_range_selected[3];
            
            this.plot_object.setScale("x", {min: x_min * this.x_factor, max: x_max * this.x_factor});
            this.plot_object.setScale("y", {min: y_min * this.y_factor, max: y_max * this.y_factor});

            // this.plot_object.redraw();  // setscale above already redraws
        }
    },

    // first setup
    setup() {
        if (this.plot_object === null) {
            let data = [[],[],];
            var opts = {
                title: "",
                id: "spectrumzoom_plot_uplot",
                ...this.getSize(),
                scales: {
                    "x": {
                        time: false,
                        auto: true,
                        range: (u, dataMin, dataMax) => {
                            return [dataMin, dataMax];
                        }
                    },
                    "y": {
                        auto: true,
                        range: (u, dataMin, dataMax) => {
                            return [dataMin, dataMax];
                        }                                
                    }
                },
                series: [
                    this.xSeries,
                    this.ySeries
                ],
                axes: [
                    {
                        values: (self, ticks) => ticks.map(rawValue => this.formatValue(rawValue, this.unit2_exponent, 2, this.x_factor)),
                    },
                    {
                        values: (self, ticks) => ticks.map(rawValue => this.formatValue(rawValue, this.unit_exponent, 2, this.y_factor)),
                    }
                ],
                cursor: {
                    drag: { x: true, y: true }  //  uni: Infinity
                }
            };
            this.plot_object = new uPlot(opts, data, this.container);

            // adjust size when container is resized
            new ResizeObserver(() => this.plot_object.setSize(this.getSize())).observe(this.container);
        } else {
            // 
        }
    }

}