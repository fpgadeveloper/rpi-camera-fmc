============
Requirements
============

In order to test this design on hardware, you will need the following:

* Vivado 2020.2
* Vitis 2020.2
* (Coming soon) PetaLinux Tools 2020.2
* One `RPi Camera FMC`_
* One or more Raspberry Pi compatible cameras (see below)
* One of the supported `target boards <supported_carriers.html>`_


Supported cameras
=================

The `RPi Camera FMC`_ is designed to support all cameras with the standard
`15-pin Raspberry Pi camera interface <https://camerafmc.com/docs/rpi-camera-fmc/detailed-description/#camera-connectors>`_,
however this example design currently only has the software support for the following:

* `Raspberry Pi Camera Module 2 <https://www.raspberrypi.com/products/camera-module-v2/>`_
* `Digilent Pcam 5C <https://digilent.com/shop/pcam-5c-5-mp-fixed-focus-color-camera-module/>`_

We're working on developing software support for more cameras. If you'd like to help with
this effort, your pull requests are more than welcome.

.. _RPi Camera FMC: https://camerafmc.com/docs/rpi-camera-fmc/overview/
