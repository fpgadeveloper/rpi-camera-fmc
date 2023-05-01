=====================
Updating the projects
=====================

This section contains instructions for updating the reference designs. It is intended as a guide
for anyone wanting to attempt updating the designs for a tools release that we do not yet support.
Note that the update process is not always straight-forward and sometimes requires dealing with
new issues or significant changes to the functionality of the tools and/or specific IP. Unfortunately, 
we cannot always provide support if you have trouble updating the designs.

Vivado projects
===============

1. Download and install the Vivado release that you intend to use.
2. If you are using one of the following boards, you will have to download and install the latest 
   board files for that target platform. Other boards are already built into Vivado and require no
   extra installation.

   * UltraZed EV board files can be downloaded `here <https://github.com/Avnet/bdf>`_
   
3. In a text editor, open the ``Vivado/build-<target>.bat`` file for
   the design that you wish to update, and perform the following changes:
   
   * Update the tools version number to the one you are using (eg. 2020.2)
   
4. In a text editor, open the ``Vivado/build.tcl`` file and perform the following changes:
   
   * Update the ``version_required`` variable value to the tools version number 
     that you are using.
   * Update the year in all references to ``Vivado Synthesis <year>`` to the 
     tools version number that you are using. For example, if you are using tools
     version 2020.2, then the ``<year>`` should be 2020.
   * Update the year in all references to ``Vivado Implementation <year>`` to the 
     tools version number that you are using. For example, if you are using tools
     version 2020.2, then the ``<year>`` should be 2020.
   * If the version of the board files for your target platform has changed, update 
     the corresponding value in the ``target_dict`` dictionary.

After following the above steps, you can now run the build script. If there were no significant changes
to the tools and/or IP, the build script should succeed and you will be able to open and generate a 
bitstream for the Vivado project.

PetaLinux
=========

Coming soon!
