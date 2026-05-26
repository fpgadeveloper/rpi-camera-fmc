# Requirements

In order to test these designs on hardware, you will need the following:

* Vivado 2025.2
* Vitis 2025.2
* Linux PC or Virtual machine (for build)
* One or more [Raspberry Pi Camera Module 2]
* One [RPi Camera FMC]
* One of the supported [target boards](supported_carriers)

Additional design-specific requirements:

* **Zynq UltraScale+ designs** (PetaLinux flow):
  * PetaLinux Tools 2025.2
  * One DisplayPort monitor supporting 1080p video

* **FPGA designs** (AUBoard 15P, baremetal flow):
  * One HDMI monitor supporting 1080p video
  * [License for the HDMI IP](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/hdmi.html)
    (a 30-day evaluation license is available)

## List of supported boards

{% set unique_boards = {} %}
{% for design in data.designs %}
	{% if design.publish %}
	    {% if design.board not in unique_boards %}
	        {% set _ = unique_boards.update({design.board: {"group": design.group, "link": design.link, "connectors": []}}) %}
	    {% endif %}
	    {% if design.connector not in unique_boards[design.board]["connectors"] %}
	    	{% set _ = unique_boards[design.board]["connectors"].append(design.connector) %}
	    {% endif %}
	{% endif %}
{% endfor %}

{% for group in data.groups %}
    {% set boards_in_group = [] %}
    {% for name, board in unique_boards.items() %}
        {% if board.group == group.label %}
            {% set _ = boards_in_group.append(board) %}
        {% endif %}
    {% endfor %}

    {% if boards_in_group | length > 0 %}
### {{ group.name }} boards

| Carrier board        | Supported FMC connector(s)    |
|---------------------|--------------|
{% for name,board in unique_boards.items() %}{% if board.group == group.label %}| [{{ name }}]({{ board.link }}) | {% for connector in board.connectors %}{{ connector }} {% endfor %} |
{% endif %}{% endfor %}
{% endif %}
{% endfor %}

For list of the target designs showing the number of cameras supported, refer to the build instructions.

## Supported cameras

The [RPi Camera FMC] is designed to support all cameras with the standard
[15-pin Raspberry Pi camera interface](https://camerafmc.com/docs/rpi-camera-fmc/detailed-description/#camera-connectors),
however these example designs currently only have the software support for the [Raspberry Pi Camera Module 2].

```{tip} We're working on developing software support for more cameras. If you'd like to help with
this effort, your pull requests are more than welcome.
```

[RPi Camera FMC]: https://docs.opsero.com/op068/datasheet/overview/
[Digilent Pcam 5C]: https://digilent.com/shop/pcam-5c-5-mp-fixed-focus-color-camera-module/
[Raspberry Pi Camera Module 2]: https://www.raspberrypi.com/products/camera-module-v2/

