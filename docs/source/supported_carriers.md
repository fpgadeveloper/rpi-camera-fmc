# Supported carrier boards

## List of supported boards

{% set unique_boards = {} %}
{% for design in data.designs %}
    {% if design.publish %}
        {% if design.board not in unique_boards %}
            {% set _ = unique_boards.update({design.board: {"group": design.group, "link": design.link, "connectors": []}}) %}
        {% endif %}
        {% set _ = unique_boards[design.board]["connectors"].append(design.connector) %}
    {% endif %}
{% endfor %}

{% for group in data.groups %}
    {% set designs_in_group = [] %}
    {% for design in data.designs %}
        {% if design.group == group.label and design.publish %}
            {% set _ = designs_in_group.append(design.label) %}
        {% endif %}
    {% endfor %}
    {% if designs_in_group | length > 0 %}
### {{ group.name }} boards

| Carrier board       | Supported FMC connector(s)    |
|---------------------|--------------|
{% for name,board in unique_boards.items() %}{% if board.group == group.label %}| [{{ name }}]({{ board.link }}) | {% for connector in board.connectors %}{{ connector }} {% endfor %} |
{% endif %}{% endfor %}
{% endif %}
{% endfor %}

For list of the target designs showing the number of cameras supported, refer to the build instructions.

## Unlisted boards

If you need more information on whether the [RPi Camera FMC] is compatible with a carrier that is not 
listed above, please first check the [compatibility list]. If the carrier is not listed there, please 
[contact Opsero], provide us with the pinout of your carrier and we'll be happy to check compatibility 
and generate a Vivado constraints file for you.

## Support for more than 4x cameras

By using more than one [RPi Camera FMC] it is possible to support more than 4x cameras on a single
target platform. At the moment however, the only target platform that can support more than 4x cameras 
in this way is the AMD Xilinx [ZCU102] Evaluation board, and it can only support a maximum of 6
cameras. This configuration is achieved as follows:

* ZCU102 HPC0 connector mates with one [RPi Camera FMC] with 4x cameras
* ZCU102 HPC1 connector mates with another [RPi Camera FMC] with 2x cameras

The limitation is due to the pinout of the HPC1 connector and there is currently no way around this.

Here are some other possibilities for supporting more than 4x cameras on a single target platform:

* Digilent [Genesys-ZU] Zynq UltraScale+ Development board can support 6x cameras with the 
  [RPi Camera FMC] because it has 2x MIPI CSI connectors.
* TUL [PYNQ-ZU] Zynq UltraScale+ Development board can support 5x cameras with the [RPi Camera FMC] 
  because it has 1x MIPI CSI connector.

## Board specific notes

### PYNQ-ZU and UltraZed EV carrier

Note that the PYNQ-ZU and UltraZed EV carrier boards have a fixed VADJ voltage that is set to 1.8VDC. The 
[AMD Xilinx MIPI CSI Controller Subsystem IP] documentation recommends an I/O voltage of 1.2VDC, and the 
Vivado tools prevent using the IP with IO standards that are not compatible with 1.2VDC. For this reason,
all of the designs in this repository use 1.2VDC compatible IO standards, even though the I/O banks on the 
PYNQ-ZU and UltraZed EV carrier boards are powered at 1.8VDC. At the moment this is the only practical and
functional workaround that we have found for these two target boards.


[contact Opsero]: https://opsero.com/contact-us
[RPi Camera FMC]: https://camerafmc.com/docs/rpi-camera-fmc/overview/
[compatibility list]: https://camerafmc.com/docs/rpi-camera-fmc/compatibility/
[AMD Xilinx MIPI CSI Controller Subsystem IP]: https://docs.xilinx.com/r/en-US/pg202-mipi-dphy

[ZCU102]: https://www.xilinx.com/zcu102
[Genesys-ZU]: https://digilent.com/shop/genesys-zu-zynq-ultrascale-mpsoc-development-board
[PYNQ-ZU]: https://www.amd.com/en/corporate/university-program/aup-boards/pynq-zu.html
