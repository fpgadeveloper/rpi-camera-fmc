Modified BSP files
==================

### DPPSU driver modifications

This project uses a modified dppsu driver. The driver `dppsu_v1_3` from version 2020.2 had a bug that prevented
a connection with DisplayPort monitors over a single lane.

We modified and bumped up the version of this driver to `dppsu_v1_39`, and this is the version used by the 
standalone application in this repo.
