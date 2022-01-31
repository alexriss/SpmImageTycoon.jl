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

    this.form_el_x_unit = document.getElementById("spectrumzoom_x_unit");
    this.form_el_y_unit = document.getElementById("spectrumzoom_y_unit");
    this.form_el_x_min = document.getElementById("spectrumzoom_x_min");
    this.form_el_x_max = document.getElementById("spectrumzoom_x_max");
    this.form_el_y_min = document.getElementById("spectrumzoom_y_min");
    this.form_el_y_max = document.getElementById("spectrumzoom_y_max");
}

SpectrumPlot.prototype = {
    // formats value (using the right exponent)
    formatValue(val, unit_exponent, decimals=2, factor=1.) {
        if (isNaN(val)) {
            return "--";
        }
        return (val / 10**unit_exponent * factor).toFixed(decimals);
    },

    // un-formats the value (using the right exponent)
    formatValueBack(val, unit_exponent, factor=1.) {
        if (isNaN(val)) {
            return NaN;
        }
        return val / factor * 10**unit_exponent;
    },

    // get size of container
    getContainerSize() {
        return {
            width: this.container.parentElement.clientWidth - 20,
            height: this.container.parentElement.clientHeight - 60
        }
    },

    // sets plot size according to container
    setPlotSize() {
        this.plot_object.setSize(this.getContainerSize());
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

            this.x_inverted = spectrum_data["x_inverted"]; 
            this.y_inverted = spectrum_data["y_inverted"];
            this.x_factor = (this.x_inverted) ? -1. : 1.;
            this.y_factor = (this.y_inverted) ? -1. : 1.;
    
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

            // full ranges
            this.x_full_min = griditem.channel_range[2];
            this.x_full_max = griditem.channel_range[3];
            this.y_full_min = griditem.channel_range[0];
            this.y_full_max = griditem.channel_range[1];
            this.x_full_min *= this.x_factor; 
            this.x_full_max *= this.x_factor; 
            this.y_full_min *= this.y_factor; 
            this.y_full_max *= this.y_factor; 

            // selected ranges
            let channel_range_selected = griditem.channel_range_selected;
            if (channel_range_selected.length != 4) {
                channel_range_selected = [0., 1., 0., 1.];
            }
            this.x_min = griditem.channel_range[2] + (griditem.channel_range[3] - griditem.channel_range[2]) * griditem.channel_range_selected[2];
            this.x_max = griditem.channel_range[2] + (griditem.channel_range[3] - griditem.channel_range[2]) * griditem.channel_range_selected[3];
            this.y_min = griditem.channel_range[0] + (griditem.channel_range[1] - griditem.channel_range[0]) * griditem.channel_range_selected[0];
            this.y_max = griditem.channel_range[0] + (griditem.channel_range[1] - griditem.channel_range[0]) * griditem.channel_range_selected[1];
            this.x_min *= this.x_factor; 
            this.x_max *= this.x_factor; 
            this.y_min *= this.y_factor; 
            this.y_max *= this.y_factor; 

            this.setPlotScale(this.x_min, this.x_max, this.y_min, this.y_max);

            this.form_el_x_unit.innerText = this.unit2_prefix +  griditem.channel2_unit;
            this.form_el_y_unit.innerText = this.unit_prefix +  griditem.channel_unit;

            if (this.x_inverted) {
                document.getElementById("spectrumzoom_x_inverted").classList.remove("is-invisible");
            } else {
                document.getElementById("spectrumzoom_x_inverted").classList.add("is-invisible");
            }
            if (this.y_inverted) {
                document.getElementById("spectrumzoom_y_inverted").classList.remove("is-invisible");
            } else {
                document.getElementById("spectrumzoom_y_inverted").classList.add("is-invisible");
            }

            // this.plot_object.redraw();  // setscale above already redraws
        }
    },

    setPlotScale(x_min, x_max, y_min, y_max) {
        this.plot_object.setScale("x", { min: x_min, max: x_max });
        this.plot_object.setScale("y", { min: y_min, max: y_max });
    },

    // handles changes in input fields
    inputEvents(e) {
        // const id = e.target.id;
        // const el = document.getElementById(id);
        // const elVal = parseFloat(el.value);
        // if (Number.isNaN(elVal)) {
        //     return;
        // }

        let x_min = this.formatValueBack(this.form_el_x_min.valueAsNumber, this.unit2_exponent, this.x_factor);
        let x_max = this.formatValueBack(this.form_el_x_max.valueAsNumber, this.unit2_exponent, this.x_factor);
        let y_min = this.formatValueBack(this.form_el_y_min.valueAsNumber, this.unit_exponent, this.y_factor);
        let y_max = this.formatValueBack(this.form_el_y_max.valueAsNumber, this.unit_exponent, this.y_factor);

        if (isNaN(x_min)) {
            x_min = this.x_min;
        }
        if (isNaN(x_max)) {
            x_max = this.x_max;
        }
        if (isNaN(y_min)) {
            y_min = this.y_min;
        }
        if (isNaN(y_max)) {
            y_max = this.y_max;
        }

        if ( x_min > x_max) {
            [x_min, x_max] = [x_max, x_min];
        }
        if (y_min > y_max) {
            [y_min, y_max] = [y_max, y_min];
        }
        // TODO: we might also check for min=max and then
        this.setPlotScale(x_min, x_max, y_min, y_max);
    },

    // first setup
    setup() {
        if (this.plot_object === null) {
            let data = [[],[],];
            var opts = {
                title: "",
                id: "spectrumzoom_plot_uplot",
                ...this.getContainerSize(),
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
                hooks: {
					setScale: [
						u => {
                                that.form_el_x_min.value = this.formatValue(u.scales.x.min, this.unit2_exponent, 3, this.x_factor);
                                that.form_el_x_max.value = this.formatValue(u.scales.x.max, this.unit2_exponent, 3, this.x_factor);
                                that.form_el_y_min.value = this.formatValue(u.scales.y.min, this.unit_exponent, 3, this.y_factor);
                                that.form_el_y_max.value = this.formatValue(u.scales.y.max, this.unit_exponent, 3, this.y_factor);
 							 }
					],
                },
                cursor: {
                    drag: { x: true, y: true }  //  uni: Infinity
                }
            };
            this.plot_object = new uPlot(opts, data, this.container);

            // adjust size when container is resized
            new ResizeObserver(() => this.setPlotSize()).observe(this.container);

            // events for scale inputs
            let that = this;
            document.querySelectorAll("#spectrumzoom_form_table input").forEach((el) => {
                el.addEventListener("change", (e) => {
                    that.inputEvents(e);
                });
            });

            // events for reset, "full-range", and save-buttons
            document.getElementById('spectrumzoom_reset_zoom').addEventListener('click', function() {
                that.setPlotScale(that.x_min, that.x_max, that.y_min, that.y_max);
            });

            document.getElementById('spectrumzoom_full_zoom').addEventListener('click', function() {
                that.setPlotScale(that.x_full_min, that.x_full_max, that.y_full_min, that.y_full_max);
            });

            document.getElementById('spectrumzoom_save_zoom').addEventListener('click', function() {

                /// todo: convert to relative ranges, also take into account inversion
                that.form_el_x_min.value, that.form_el_x_max.value, that.form_el_y_min.value, that.form_el_y_max.value
                const range_selected_abs = [
                    that.plot_object.scales.y.min,
                    that.plot_object.scales.y.max,
                    that.plot_object.scales.x.min,
                    that.plot_object.scales.x.max,
                ];
                let range_selected_rel = [
                    (range_selected_abs[0] - that.y_full_min) / (that.y_full_max - that.y_full_min),
                    (range_selected_abs[1] - that.y_full_min) / (that.y_full_max - that.y_full_min),
                    (range_selected_abs[2] - that.x_full_min) / (that.x_full_max - that.x_full_min),
                    (range_selected_abs[3] - that.x_full_min) / (that.x_full_max - that.x_full_min),
                ]
               
                // call julia
                change_spectrum_range(window.zoom_last_selected, range_selected_rel);
            });
        } else {
            // 
        }
    }

}
