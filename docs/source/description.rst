============
Description
============

This reference design demonstrates the use of the RPi Camera FMC with 4x cameras and 1x DisplayPort monitor 
attached. The video streams coming from each camera pass through a video pipe composed of the 
`AMD Xilinx MIPI CSI Controller Subsystem IP`_ and other video processing IP. The 4x video streams pass
through an AXIS switch which is used to select (via software) the video to display on the monitor.

FPGA (hardware) design
======================

The hardware design for these projects is built in Vivado and is composed of IP that implement the
MIPI interface with the cameras, as well as a video pipe and signal generation for the DisplayPort
monitor. The block diagram below illustrates the design from the top level.

.. figure:: images/block-diagram-top-level.png
    :align: center
    :name: block-diagram-top-level
    
    RPi Camera FMC design block diagram
    
The block diagram below illustrates the video pipe:

.. figure:: images/video-pipe-block-diagram.png
    :align: center
    :name: video-pipe-block-diagram
    
    Video pipe sub-block diagram
    
.. _AMD Xilinx MIPI CSI Controller Subsystem IP: https://docs.xilinx.com/r/en-US/pg202-mipi-dphy

Software design
===============

Software is needed to configure the cameras over the I2C buses, to setup the video pipes and to establish
a link with the DisplayPort monitor. This project currently has a standalone application to do these things,
however there will soon be a PetaLinux project which will enable much more functionality.

More information regarding the standalone application can be found `here <standalone.html>`_.
