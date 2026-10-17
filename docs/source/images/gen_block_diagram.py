#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Opsero Electronic Design Inc.
"""
Generate the block diagrams for the Opsero RPi Camera FMC reference design docs.

Facts drawn here come from the block-design scripts:
  Vivado/src/bd/bd_zynqmp.tcl  (Zynq UltraScale+ targets)
  Vivado/src/bd/bd_mb.tcl      (MicroBlaze target, AUBoard 15P)

Zynq UltraScale+ (per camera, hierarchy mipi_<n>):
  MIPI CSI-2 RX Subsystem (2 lanes, RAW10) -> AXI4-Stream Data FIFO -> ISP Pipeline
  (Vitis Vision ISPPipeline_accel, HLS) -> Video Processing Subsystem (scaler + CSC)
  -> Frame Buffer Write -> SmartConnect -> S_AXI_HPC0_FPD -> DDR.
  Display (hierarchy display_pipeline): Video Mixer (4 YUYV memory layers + 1 RGBA
  logo/alpha layer, YUV 4:2:2 out) reads DDR through S_AXI_HP3_FPD -> AXI4-Stream
  Subset Converter (24 -> 16 bit) -> AXI4-Stream to Video Out, timed by the Video
  Timing Controller -> DisplayPort live video input of the PS (DPSUB).  A dynamically
  reconfigurable Clocking Wizard (clk_in1 = 250 MHz) makes the video clock.
  VCU on the ZCU104, ZCU106 and UltraZed-EV targets.

MicroBlaze (AUBoard 15P, baremetal):
  MIPI CSI-2 RX -> AXI4-Stream Subset Converter -> Demosaic -> Gamma LUT -> VPSS ->
  Frame Buffer Write -> DDR4 -> Frame Buffer Read -> Video Mixer (TPG on the master
  layer) -> HDMI 1.4/2.0 TX Subsystem -> Video PHY Controller (GTH) -> HDMI monitor.

Writes these PNGs next to this script (docs/source/images/):
  rpi-camera-fmc-architecture.png       top level, Zynq UltraScale+ designs
  rpi-camera-fmc-mipi-pipeline.png      one capture pipeline, Zynq UltraScale+
  rpi-camera-fmc-display-pipeline.png   display pipeline, Zynq UltraScale+
  rpi-camera-fmc-end-to-end.png         formats and resolutions, source to sink
  rpi-camera-fmc-simple-pipeline.png    one capture pipeline, MicroBlaze (AUBoard)
  rpi-camera-fmc-hdmi-display-pipe.png  display pipeline, MicroBlaze (AUBoard)

Usage (from anywhere):
    python3 docs/source/images/gen_block_diagram.py
"""

import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, FancyArrowPatch
from matplotlib.lines import Line2D

# ---- palette (shared with the other Opsero reference-design block diagrams) --
C_PS_FILL      = "#D9D9D9"; C_PS_EDGE      = "#7F7F7F"   # processor / DDR column
C_FAB_FILL     = "#F2F2F2"; C_FAB_EDGE     = "#BFBFBF"   # FPGA fabric container
C_IP_FILL      = "#E8E8F2"; C_IP_EDGE      = "#8C8CC0"   # PL video IP (lavender)
C_HARD_FILL    = "#F3EFE2"; C_HARD_EDGE    = "#BFB585"   # hard blocks: DPSUB, VCU, GT
C_FMC_FILL     = "#DCE6F2"; C_FMC_EDGE     = "#9DB7D4"   # external FMC / cameras
C_EXT_FILL     = "#FFFFFF"                                # external devices
C_CLK_FILL     = "#FDE9D9"; C_CLK_EDGE     = "#E0B090"   # clocking (peach)
C_CTRL_FILL    = "#ECECEC"; C_CTRL_EDGE    = "#BFBFBF"   # control plane
C_AXARR_FILL   = "#EDF3D4"; C_AXARR_EDGE   = "#A6B85A"   # AXI-MM arrows (pale green)
C_LINKARR_FILL = "#DAE8F5"; C_LINKARR_EDGE = "#6F9FCF"   # serial links (pale blue)
C_DPARR_FILL   = "#D5E6A3"; C_DPARR_EDGE   = "#7F9A2E"   # video stream arrows
C_REFCLK_LINE  = "#C8823C"                                # clock nets (orange)
C_CTRL_LINE    = "#8C8C8C"                                # control nets (grey)
TXT = "#1A1A1A"
TXT2 = "#404040"


# ---- helpers -----------------------------------------------------------------
def new_fig(w, h, xlim, ylim):
    fig, ax = plt.subplots(figsize=(w, h), dpi=120)
    ax.set_xlim(0, xlim)
    ax.set_ylim(0, ylim)
    ax.axis("off")
    return fig, ax


def save(fig, name):
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), name)
    fig.savefig(out, bbox_inches="tight", pad_inches=0.15, facecolor="white")
    plt.close(fig)
    print("wrote", out)


def box(ax, x, y, w, h, fc, ec, label="", fs=9, rot=0, lw=1.2, weight="normal",
        txtcolor=None, ls="-", z=2):
    ax.add_patch(plt.Rectangle((x, y), w, h, fc=fc, ec=ec, lw=lw, ls=ls, zorder=z))
    if label:
        ax.text(x + w / 2, y + h / 2, label, ha="center", va="center",
                fontsize=fs, rotation=rot, color=txtcolor or TXT, weight=weight,
                zorder=z + 1, linespacing=1.25)


def titled_box(ax, x, y, w, h, fc, ec, title, body, title_fs=9.0, body_fs=7.4,
               lw=1.2, txtcolor=None, title_dy=2.4, ls="-", z=2):
    """A box with a bold title line at the top and a smaller body below it."""
    box(ax, x, y, w, h, fc, ec, "", lw=lw, ls=ls, z=z)
    cx = x + w / 2
    ax.text(cx, y + h - title_dy, title, ha="center", va="center",
            fontsize=title_fs, weight="bold", color=txtcolor or TXT, zorder=z + 1,
            linespacing=1.15)
    if body:
        ax.text(cx, y + (h - title_dy * 1.9) / 2, body, ha="center", va="center",
                fontsize=body_fs, color=txtcolor or TXT, zorder=z + 1,
                linespacing=1.3)


def container(ax, x, y, w, h, fc, ec, title, fs=11.5, lw=1.3):
    """Large region (fabric, PS, external) with its title above the top edge."""
    ax.add_patch(plt.Rectangle((x, y), w, h, fc=fc, ec=ec, lw=lw, zorder=1))
    ax.text(x + w / 2, y + h + 0.8, title, ha="center", va="bottom", fontsize=fs,
            weight="bold", color=TXT)


def harrow(ax, x0, x1, yc, label="", fc=C_DPARR_FILL, ec=C_DPARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.6, fs=7.2, lw=1.0, lab_dy=0.0, lab_color=None):
    """Horizontal block arrow, head at x1 (both ends when double)."""
    if double:
        pts = [(x0, yc), (x0 + hl, yc + hh), (x0 + hl, yc + bh),
               (x1 - hl, yc + bh), (x1 - hl, yc + hh), (x1, yc),
               (x1 - hl, yc - hh), (x1 - hl, yc - bh),
               (x0 + hl, yc - bh), (x0 + hl, yc - hh)]
    else:
        s = 1.0 if x1 >= x0 else -1.0
        neck = x1 - s * hl
        pts = [(x0, yc + bh), (neck, yc + bh), (neck, yc + hh),
               (x1, yc), (neck, yc - hh), (neck, yc - bh), (x0, yc - bh)]
    ax.add_patch(Polygon(pts, closed=True, fc=fc, ec=ec, lw=lw, zorder=2))
    if label:
        ax.text((x0 + x1) / 2, yc + lab_dy, label, ha="center", va="center",
                fontsize=fs, color=lab_color or TXT, zorder=3, linespacing=1.15)


def varrow(ax, xc, y0, y1, fc=C_DPARR_FILL, ec=C_DPARR_EDGE, double=False,
           bw=1.0, hw=1.9, hl=1.6, lw=1.0):
    """Vertical block arrow, head at y1 (both ends when double)."""
    if double:
        lo, hi = min(y0, y1), max(y0, y1)
        pts = [(xc, lo), (xc + hw, lo + hl), (xc + bw, lo + hl),
               (xc + bw, hi - hl), (xc + hw, hi - hl), (xc, hi),
               (xc - hw, hi - hl), (xc - bw, hi - hl),
               (xc - bw, lo + hl), (xc - hw, lo + hl)]
    else:
        s = 1.0 if y1 >= y0 else -1.0
        neck = y1 - s * hl
        pts = [(xc - bw, y0), (xc - bw, neck), (xc - hw, neck), (xc, y1),
               (xc + hw, neck), (xc + bw, neck), (xc + bw, y0)]
    ax.add_patch(Polygon(pts, closed=True, fc=fc, ec=ec, lw=lw, zorder=2))


def route(ax, pts, color, lw=1.4, head=True, ls="-"):
    """Thin elbow line through pts (arrow head at the last point)."""
    if head:
        xs, ys = zip(*pts[:-1])
        ax.add_line(Line2D(xs, ys, color=color, lw=lw, ls=ls, zorder=3,
                           solid_capstyle="butt", solid_joinstyle="miter"))
        ax.add_patch(FancyArrowPatch(pts[-2], pts[-1], arrowstyle="-|>",
                                     mutation_scale=10, lw=lw, color=color,
                                     zorder=3, shrinkA=0, shrinkB=0))
    else:
        xs, ys = zip(*pts)
        ax.add_line(Line2D(xs, ys, color=color, lw=lw, ls=ls, zorder=3,
                           solid_capstyle="butt", solid_joinstyle="miter"))


def note(ax, x, y, text, fs=6.8, color=TXT2, ha="center", rot=0, weight="normal"):
    ax.text(x, y, text, ha=ha, va="center", fontsize=fs, color=color, zorder=4,
            linespacing=1.25, rotation=rot, weight=weight)


def legend(ax, x, y, items, fs=7.2, sw=3.2, sh=2.0, dx=26.0):
    """One row of colour swatches: items = [(fill, edge, label), ...]."""
    for i, (fc, ec, lab) in enumerate(items):
        xi = x + i * dx
        ax.add_patch(plt.Rectangle((xi, y), sw, sh, fc=fc, ec=ec, lw=1.0, zorder=2))
        ax.text(xi + sw + 0.8, y + sh / 2, lab, ha="left", va="center",
                fontsize=fs, color=TXT, zorder=3)


# ---- 1. top level, Zynq UltraScale+ ------------------------------------------
def fig_architecture():
    fig, ax = new_fig(17.0, 11.2, 170, 112)

    # external: RPi Camera FMC with four cameras
    container(ax, 2, 30, 24, 72, C_FMC_FILL, C_FMC_EDGE, "External")
    note(ax, 14, 98.5, "RPi Camera FMC\n(OP068)", fs=8.6, color=TXT, weight="bold")
    note(ax, 14, 33.8, "2-lane MIPI CSI-2\n+ I2C + GPIO\nper camera", fs=6.6)
    cam_y = [84, 70, 56, 42]
    for i, y in enumerate(cam_y):
        titled_box(ax, 4, y, 20, 10, C_EXT_FILL, C_FMC_EDGE, f"CAM{i}",
                   "IMX219\n(RPi camera v2)", title_fs=8.4, body_fs=6.8,
                   title_dy=2.2)

    # fabric
    fx0, fx1 = 30, 116
    container(ax, fx0, 2, fx1 - fx0, 100, C_FAB_FILL, C_FAB_EDGE,
              "Programmable logic (PL)")

    # four capture pipelines
    for i, y in enumerate(cam_y):
        titled_box(ax, 33, y, 52, 10, C_IP_FILL, C_IP_EDGE,
                   f"mipi_{i}:  capture pipeline (CAM{i})",
                   "CSI-2 RX → FIFO → ISP Pipeline → VPSS (scaler + CSC)\n"
                   "→ Frame Buffer Write        + AXI IIC, AXI GPIO",
                   title_fs=8.0, body_fs=6.6, title_dy=2.1)
        harrow(ax, 24, 33, y + 5, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE,
               bh=0.9, hh=1.7, hl=1.4)
        harrow(ax, 85, 89, y + 5, fc=C_AXARR_FILL, ec=C_AXARR_EDGE,
               bh=0.8, hh=1.6, hl=1.2)
    box(ax, 89, 42, 7, 52, C_IP_FILL, C_IP_EDGE, "SmartConnect\n(smartconnect_cams)",
        fs=7.2, rot=90)
    note(ax, 59, 39.2, "Two-camera targets build only the pipelines they use:\n"
         "zcu102_hpc1 = CAM0, CAM1   ·   pynqzu = CAM1, CAM2", fs=6.6)

    # display pipeline
    titled_box(ax, 33, 18, 52, 17, C_IP_FILL, C_IP_EDGE, "display_pipeline",
               "Video Mixer: 4 YUYV memory layers (one per camera)\n"
               "+ 1 RGBA layer, YUV 4:2:2 out, 1080p\n"
               "→ Subset Converter → AXI4-Stream to Video Out\n"
               "Video Timing Controller · Clocking Wizard (pixel clock)",
               title_fs=8.4, body_fs=6.8, title_dy=2.3)
    harrow(ax, 89, 85, 24, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=0.8, hh=1.6, hl=1.2)
    box(ax, 89, 20, 7, 8, C_IP_FILL, C_IP_EDGE, "AXI IC", fs=6.6, rot=90)

    # VCU (some targets)
    titled_box(ax, 33, 4, 52, 11, C_HARD_FILL, C_HARD_EDGE,
               "VCU  (ZCU104, ZCU106, UltraZed-EV)",
               "H.264 / H.265 video codec unit: encoder + decoder\n"
               "+ MCU, AXI interconnects",
               title_fs=8.2, body_fs=6.8, title_dy=2.2)

    # control and clocks column
    titled_box(ax, 99, 74, 15, 20, C_CTRL_FILL, C_CTRL_EDGE, "Control",
               "AXI-Lite (100 MHz\nand 250 MHz)\nAXI Intc\n→ pl_ps_irq0\nEMIO GPIO:\nIP resets",
               title_fs=8.2, body_fs=6.4, title_dy=2.2)
    titled_box(ax, 99, 40, 15, 24, C_CLK_FILL, C_CLK_EDGE, "clk_wiz_0",
               "in: pl_clk0\n(100 MHz)\n200 MHz D-PHY\n250 MHz video\n100 MHz AXI-Lite\n"
               "50 MHz VCU ref", title_fs=8.2, body_fs=6.3, title_dy=2.2)

    # PS
    px0, px1 = 120, 146
    container(ax, px0, 2, px1 - px0, 100, C_PS_FILL, C_PS_EDGE,
              "Processing system (PS)")
    titled_box(ax, 122, 86, 22, 14, "#EAEAEA", C_PS_EDGE, "Arm Cortex-A53",
               "Linux (PetaLinux or\nYocto / AMD EDF)\nV4L2 media + DRM",
               title_fs=8.6, body_fs=6.6, title_dy=2.4)
    ports = [(68, "S_AXI_HPC0_FPD"), (24, "S_AXI_HP3_FPD"),
             (10, "S_AXI_HP1/2_FPD\nS_AXI_LPD")]
    for y, name in ports:
        box(ax, 122, y - 3.5, 22, 7, "#EAEAEA", C_PS_EDGE, name, fs=6.8)
    harrow(ax, 96, 122, 68, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=1.0, hh=1.9, hl=1.6)
    note(ax, 109, 70.6, "frame buffer writes", fs=6.2)
    harrow(ax, 122, 96, 24, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=1.0, hh=1.9, hl=1.6)
    note(ax, 109, 26.6, "mixer layer reads", fs=6.2)
    harrow(ax, 85, 122, 10, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=1.0, hh=1.9, hl=1.6)
    box(ax, 122, 76, 22, 8, "#EAEAEA", C_PS_EDGE, "M_AXI_HPM0_FPD\nM_AXI_HPM0_LPD",
        fs=6.8)
    route(ax, [(122, 80), (114, 80)], C_CTRL_LINE)
    note(ax, 118.0, 82.0, "AXI-Lite", fs=6.0, color=C_CTRL_LINE)
    box(ax, 122, 49, 22, 6, "#EAEAEA", C_PS_EDGE, "pl_clk0, pl_resetn0", fs=6.6)
    route(ax, [(122, 52), (114, 52)], C_REFCLK_LINE)
    box(ax, 122, 30, 22, 9, "#EAEAEA", C_PS_EDGE, "DP live video in\n→ DPSUB", fs=6.8)
    route(ax, [(85, 33), (89, 33), (89, 34.5), (122, 34.5)], C_DPARR_EDGE, lw=1.8)
    note(ax, 106, 36.5, "YUV 4:2:2 live video\n+ pixel clock", fs=6.2,
         color=C_DPARR_EDGE)

    # external right: DDR, monitor, network
    ex0 = 150
    container(ax, ex0, 2, 18, 100, C_FMC_FILL, C_FMC_EDGE, "On the board")
    titled_box(ax, 151.5, 64, 15, 26, C_EXT_FILL, C_FMC_EDGE, "DDR4",
               "PS memory:\nframe buffers,\nCMA\n(cma=1536M;\n1000M on\nUltraZed-EV)",
               title_fs=8.6, body_fs=6.6, title_dy=2.4)
    harrow(ax, 146, 151.5, 77, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, double=True,
           bh=1.0, hh=1.9, hl=1.3)
    titled_box(ax, 151.5, 46, 15, 14, C_EXT_FILL, C_FMC_EDGE, "Network",
               "board Ethernet\n(PS GEM)\nPYNQ-ZU: Wi-Fi", title_fs=8.4, body_fs=6.6,
               title_dy=2.4)
    harrow(ax, 146, 151.5, 53, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, double=True,
           bh=1.0, hh=1.9, hl=1.3)
    titled_box(ax, 151.5, 26, 15, 16, C_EXT_FILL, C_FMC_EDGE, "DisplayPort",
               "monitor\n1080p60", title_fs=8.4, body_fs=6.8, title_dy=2.4)
    harrow(ax, 146, 151.5, 34.5, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, bh=1.0, hh=1.9,
           hl=1.3)
    titled_box(ax, 151.5, 5, 15, 13, C_EXT_FILL, C_FMC_EDGE, "USB-UART",
               "console\n115200 8N1", title_fs=8.4, body_fs=6.6, title_dy=2.4)
    harrow(ax, 146, 151.5, 11.5, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, double=True,
           bh=1.0, hh=1.9, hl=1.3)

    for k, item in enumerate([(C_IP_FILL, C_IP_EDGE, "PL video IP"),
                              (C_HARD_FILL, C_HARD_EDGE, "hardened block"),
                              (C_CLK_FILL, C_CLK_EDGE, "clocking"),
                              (C_CTRL_FILL, C_CTRL_EDGE, "control"),
                              (C_PS_FILL, C_PS_EDGE, "processing system"),
                              (C_FMC_FILL, C_FMC_EDGE, "external")]):
        legend(ax, 3, 25 - k * 4, [item])
    save(fig, "rpi-camera-fmc-architecture.png")


# ---- 2. one capture pipeline, Zynq UltraScale+ --------------------------------
def fig_mipi_pipeline():
    fig, ax = new_fig(17.0, 6.6, 170, 66)
    container(ax, 22, 2, 122, 58, C_FAB_FILL, C_FAB_EDGE,
              "Capture pipeline mipi_<n>  (one per camera, in the PL)")
    yc, h = 42, 14
    y0 = yc - h / 2
    titled_box(ax, 2, y0, 16, h, C_FMC_FILL, C_FMC_EDGE, "RPi camera",
               "IMX219 sensor\non CAM<n> of\nthe RPi Camera FMC", title_fs=8.6,
               body_fs=6.8)
    blocks = [
        (24, 19, "MIPI CSI-2 RX\nSubsystem", "2-lane D-PHY\nRAW10\n1 pixel/clock"),
        (47, 13, "AXI4-Stream\nData FIFO", "depth 4096"),
        (64, 21, "ISP Pipeline", "Vitis Vision HLS core:\nblack level, gain,\ndemosaic, AWB,\n"
                                 "CCM, gamma"),
        (89, 21, "Video Processing\nSubsystem", "scaler + colour\nspace conversion\nmax 1920 x 1232"),
        (114, 16, "Frame Buffer\nWrite", "YUYV, NV12,\nBGR8\n128-bit AXI-MM"),
    ]
    for x, w, t, b in blocks:
        titled_box(ax, x, y0, w, h, C_IP_FILL, C_IP_EDGE, t, b, title_fs=7.8,
                   body_fs=6.5, title_dy=3.0)
    harrow(ax, 18, 24, yc, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, bh=1.1, hh=2.0,
           hl=1.5)
    note(ax, 21, yc + 4.6, "CSI-2", fs=6.4)
    for (xa, wa, *_), (xb, *_r) in zip(blocks[:-1], blocks[1:]):
        harrow(ax, xa + wa, xb, yc, fc=C_DPARR_FILL, ec=C_DPARR_EDGE, bh=1.0, hh=1.9,
               hl=1.3)
    # formats on the streams
    fmts = [(45.5, "RAW10\nSRGGB10"), (62.5, "RAW10"), (87, "RGB\nRBG888_1X24"),
            (112, "YUY2\nUYVY8_1X16")]
    for x, t in fmts:
        note(ax, x, yc + h / 2 + 3.2, t, fs=6.2)
    # to DDR
    titled_box(ax, 150, y0, 18, h, C_PS_FILL, C_PS_EDGE, "PS → DDR",
               "SmartConnect\n→ S_AXI_HPC0_FPD", title_fs=8.4, body_fs=6.6)
    harrow(ax, 130, 150, yc, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=1.1, hh=2.0, hl=1.5)
    note(ax, 140, yc + 4.2, "frames", fs=6.4)

    # control row
    cy0, ch = 8, 12
    titled_box(ax, 24, cy0, 19, ch, C_CTRL_FILL, C_CTRL_EDGE, "AXI IIC",
               "camera I2C bus\n(imx219 driver)", title_fs=7.8, body_fs=6.5)
    titled_box(ax, 47, cy0, 13, ch, C_CTRL_FILL, C_CTRL_EDGE, "AXI GPIO",
               "2 outputs:\ncamera GPIO", title_fs=7.8, body_fs=6.5)
    titled_box(ax, 64, cy0, 46, ch, C_CTRL_FILL, C_CTRL_EDGE,
               "Resets from PS EMIO GPIO",
               "ISP = 8(n+1),  VPSS = 8(n+1)+1,  Frame Buffer Write = 8(n+1)+2\n"
               "(the Linux drivers release them)", title_fs=7.8, body_fs=6.5)
    titled_box(ax, 114, cy0, 28, ch, C_CLK_FILL, C_CLK_EDGE, "Clocks",
               "D-PHY 200 MHz\nvideo + AXI4-Stream 250 MHz\nAXI-Lite (CSI-2, IIC, GPIO) 100 MHz",
               title_fs=7.8, body_fs=6.4)
    route(ax, [(10, y0), (10, 14), (24, 14)], C_CTRL_LINE)
    note(ax, 13, 16.2, "I2C", fs=6.2, color=C_CTRL_LINE)
    note(ax, 83, 26.5, "interrupts (CSI-2, ISP, Frame Buffer Write, IIC) → AXI Intc → PS",
         fs=6.4)
    save(fig, "rpi-camera-fmc-mipi-pipeline.png")


# ---- 3. display pipeline, Zynq UltraScale+ -------------------------------------
def fig_display_pipeline():
    fig, ax = new_fig(17.0, 8.6, 170, 86)
    container(ax, 2, 2, 116, 78, C_FAB_FILL, C_FAB_EDGE,
              "display_pipeline  (PL)")
    container(ax, 122, 2, 26, 78, C_PS_FILL, C_PS_EDGE, "PS")
    container(ax, 152, 2, 16, 78, C_FMC_FILL, C_FMC_EDGE, "External")

    # mixer
    mx, my, mw, mh = 54, 34, 24, 34
    titled_box(ax, mx, my, mw, mh, C_IP_FILL, C_IP_EDGE, "Video Mixer",
               "\nlayer 0: primary\n(NV16, DRM)\nlayers 1-4: YUYV\n(one per camera)\n"
               "layer 5: RGBA\n(alpha)\n\nout: YUV 4:2:2\nmax 3840 x 2160\nbackground: blue",
               title_fs=8.8, body_fs=6.6, title_dy=2.6)
    # AXI interconnect for the 5 MM layer reads
    box(ax, 84, my + 4, 7, mh - 8, C_IP_FILL, C_IP_EDGE, "AXI Interconnect",
        fs=6.8, rot=90)
    for k in range(5):
        yy = my + 8 + k * 4.5
        route(ax, [(mx + mw, yy), (84, yy)], C_AXARR_EDGE, lw=1.2, head=False)
    note(ax, 81, my + mh - 1.5, "5 AXI-MM\nreaders", fs=6.2)
    titled_box(ax, 124, 46, 22, 10, "#EAEAEA", C_PS_EDGE, "S_AXI_HP3_FPD",
               "→ DDR", title_fs=7.8, body_fs=6.6)
    harrow(ax, 124, 91, 51, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=1.0, hh=1.9, hl=1.5)
    note(ax, 107, 54.5, "camera frames from DDR", fs=6.4)

    # stream path to DP
    titled_box(ax, 30, 40, 18, 16, C_IP_FILL, C_IP_EDGE, "AXI4-Stream\nSubset Conv.",
               "24 → 16 bit\n(YUV 4:2:2)", title_fs=7.6, body_fs=6.4, title_dy=3.4)
    harrow(ax, mx, 48, 48, fc=C_DPARR_FILL, ec=C_DPARR_EDGE, bh=1.0, hh=1.9, hl=1.4)
    titled_box(ax, 6, 40, 18, 16, C_IP_FILL, C_IP_EDGE, "AXI4-Stream\nto Video Out",
               "async clock,\nVTG slave", title_fs=7.6, body_fs=6.4, title_dy=3.4)
    harrow(ax, 30, 24, 48, fc=C_DPARR_FILL, ec=C_DPARR_EDGE, bh=1.0, hh=1.9, hl=1.4)
    titled_box(ax, 6, 14, 18, 16, C_IP_FILL, C_IP_EDGE, "Video Timing\nController",
               "1080p timing\ngenerator", title_fs=7.6, body_fs=6.4, title_dy=3.4)
    varrow(ax, 15, 30, 40, fc=C_CTRL_FILL, ec=C_CTRL_EDGE, bw=0.9, hw=1.7, hl=1.3)
    note(ax, 20.5, 35, "timing", fs=6.2)
    # clocking wizard
    titled_box(ax, 30, 8, 24, 22, C_CLK_FILL, C_CLK_EDGE, "Clocking Wizard",
               "dynamic reconfiguration\n(clk-wizard driver)\n\nclk_in1: 250 MHz\n"
               "out: ~262.7 MHz at boot\n148.5 MHz after the\n1080p60 mode set",
               title_fs=8.2, body_fs=6.4, title_dy=2.4)
    route(ax, [(30, 19), (26.5, 19), (26.5, 22), (24, 22)], C_REFCLK_LINE)
    route(ax, [(42, 30), (42, 36), (26.5, 36), (26.5, 44), (24, 44)], C_REFCLK_LINE)
    note(ax, 36.5, 33.4, "video clock", fs=6.2, color=C_REFCLK_LINE)
    note(ax, 42, 5.0, "lock → reset of the VTC", fs=6.2, color=C_REFCLK_LINE)

    # DP live input
    titled_box(ax, 124, 20, 22, 18, "#EAEAEA", C_PS_EDGE, "DPSUB",
               "DP live video input\n(YUV 4:2:2, 8 bpc)\n+ dp_video_in_clk\n→ PS-GTR lanes",
               title_fs=8.2, body_fs=6.4, title_dy=2.4)
    route(ax, [(6, 44), (4.4, 44), (4.4, 4.5), (120, 4.5), (120, 29), (124, 29)],
          C_DPARR_EDGE, lw=1.8, head=True)
    note(ax, 72, 6.6, "pixel data, hsync, vsync, data enable, video clock", fs=6.4,
         color=C_DPARR_EDGE)
    titled_box(ax, 153.5, 20, 13, 18, C_EXT_FILL, C_FMC_EDGE, "Monitor",
               "DisplayPort\n1920 x 1080\n60 Hz", title_fs=8.2, body_fs=6.4)
    harrow(ax, 146, 153.5, 29, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, bh=1.0, hh=1.9,
           hl=1.3)

    # control
    titled_box(ax, 124, 62, 22, 14, "#EAEAEA", C_PS_EDGE, "AXI-Lite control",
               "M_AXI_HPM0_FPD: mixer\nM_AXI_HPM0_LPD: VTC,\nClocking Wizard",
               title_fs=7.8, body_fs=6.4)
    route(ax, [(124, 72), (66, 72), (66, 68)], C_CTRL_LINE)
    route(ax, [(124, 66), (100, 66), (100, 76), (60, 76), (60, 78), (2.8, 78),
               (2.8, 22), (6, 22)], C_CTRL_LINE, ls="--")
    note(ax, 95, 73.6, "mixer registers", fs=6.2, color=C_CTRL_LINE)
    note(ax, 30, 79.4, "VTC + Clocking Wizard registers", fs=6.2, color=C_CTRL_LINE)
    note(ax, 98, 22, "reset: EMIO GPIO 1 (mixer)\ninterrupts: mixer, VTC\n→ pl_ps_irq1",
         fs=6.4)
    save(fig, "rpi-camera-fmc-display-pipeline.png")


# ---- 4. end-to-end formats ------------------------------------------------------
def fig_end_to_end():
    fig, ax = new_fig(17.0, 8.0, 170, 80)
    rows = [64, 50, 36, 22]
    h = 9
    cols = [(2, 13, C_FMC_FILL, C_FMC_EDGE, "RPi camera\n(IMX219)"),
            (21, 15, C_IP_FILL, C_IP_EDGE, "MIPI CSI-2 RX\n+ FIFO"),
            (42, 14, C_IP_FILL, C_IP_EDGE, "ISP Pipeline"),
            (62, 15, C_IP_FILL, C_IP_EDGE, "VPSS\n(scaler + CSC)"),
            (83, 14, C_IP_FILL, C_IP_EDGE, "Frame Buffer\nWrite")]
    for i, y in enumerate(rows):
        for k, (x, w, fc, ec, t) in enumerate(cols):
            box(ax, x, y, w, h, fc, ec, t if k else f"CAM{i}\n" + t.split("\n")[1],
                fs=7.0)
        for (xa, wa, *_), (xb, *_r) in zip(cols[:-1], cols[1:]):
            harrow(ax, xa + wa, xb, y + h / 2, bh=0.8, hh=1.6, hl=1.2)
        harrow(ax, 97, 103, y + h / 2, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=0.8,
               hh=1.6, hl=1.2)
    box(ax, 103, 22, 9, 51, C_PS_FILL, C_PS_EDGE, "DDR", fs=9.5, weight="bold",
        rot=90)
    box(ax, 118, 41, 14, 12, C_IP_FILL, C_IP_EDGE, "Video Mixer", fs=7.6)
    harrow(ax, 112, 118, 47, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=0.9, hh=1.7, hl=1.3)
    box(ax, 138, 41, 13, 12, C_HARD_FILL, C_HARD_EDGE, "DPSUB\n(DP live)", fs=7.6)
    harrow(ax, 132, 138, 47, bh=0.9, hh=1.7, hl=1.3)
    box(ax, 157, 41, 11, 12, C_FMC_FILL, C_FMC_EDGE, "Monitor", fs=7.6)
    harrow(ax, 151, 157, 47, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, bh=0.9, hh=1.7,
           hl=1.3)

    # format labels at each interface (displaycams.sh settings)
    labs = [(18, "RAW10\n1920x1080\n30 fps"), (39, "RAW10\n1920x1080"),
            (59, "RGB888\n1920x1080"), (80, "YUY2\n960x540"),
            (100, "YUY2\n960x540"), (115, "4x YUY2\n960x540"),
            (135, "YUV 4:2:2\n1920x1080"), (154, "1080p60")]
    for x, t in labs:
        ax.add_patch(plt.Rectangle((x - 2.6, 75 - 0.2), 5.2, 0.4, fc=C_DPARR_EDGE,
                                   ec="none", zorder=2))
        note(ax, x, 78.0, t, fs=6.4, color=TXT)
        route(ax, [(x, 74.6), (x, 18)], "#C9C9C9", lw=0.9, head=False, ls=":")
    note(ax, 85, 12.5,
         "Formats shown as displaycams.sh sets them (each camera scaled to one 960 x 540 "
         "quadrant of the 1080p monitor).\n"
         "init_cams.sh defaults to 1920x1080 YUY2 at the VPSS output instead. "
         "The camera and VPSS resolutions/formats can be changed at run time with "
         "media-ctl.", fs=7.0)
    note(ax, 85, 5.0, "Two-camera targets (zcu102_hpc1, pynqzu) have two rows; "
         "displaycams.sh then fills the top two quadrants.", fs=7.0)
    save(fig, "rpi-camera-fmc-end-to-end.png")


# ---- 5. one capture pipeline, MicroBlaze (AUBoard) ------------------------------
def fig_simple_pipeline():
    fig, ax = new_fig(17.0, 5.2, 170, 52)
    container(ax, 22, 2, 124, 44, C_FAB_FILL, C_FAB_EDGE,
              "Capture pipeline mipi_<n>  (AUBoard 15P, MicroBlaze design)")
    yc, h = 30, 14
    y0 = yc - h / 2
    titled_box(ax, 2, y0, 16, h, C_FMC_FILL, C_FMC_EDGE, "RPi camera",
               "CAM0 or CAM2\nof the RPi\nCamera FMC", title_fs=8.4, body_fs=6.8)
    blocks = [(24, 15, "MIPI CSI-2 RX\nSubsystem", "RAW10"),
              (42, 14, "AXI4-Stream\nSubset Conv.", "RAW10 → 8 bit"),
              (59, 13, "Demosaic", "Bayer → RGB"),
              (75, 13, "Gamma LUT", ""),
              (91, 17, "Video Processing\nSubsystem", "scaler"),
              (111, 15, "Frame Buffer\nWrite", "")]
    for x, w, t, b in blocks:
        titled_box(ax, x, y0, w, h, C_IP_FILL, C_IP_EDGE, t, b, title_fs=7.6,
                   body_fs=6.4, title_dy=3.0)
    harrow(ax, 18, 24, yc, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, bh=1.1, hh=2.0, hl=1.5)
    for (xa, wa, *_), (xb, *_r) in zip(blocks[:-1], blocks[1:]):
        harrow(ax, xa + wa, xb, yc, bh=1.0, hh=1.9, hl=1.2)
    titled_box(ax, 150, y0, 18, h, C_PS_FILL, C_PS_EDGE, "DDR4", "via the MIG\n(ddr4_0)",
               title_fs=8.4, body_fs=6.6)
    harrow(ax, 126, 150, yc, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=1.1, hh=2.0, hl=1.5)
    titled_box(ax, 111, 6, 15, 12, C_IP_FILL, C_IP_EDGE, "Frame Buffer\nRead",
               "→ Video Mixer", title_fs=7.6, body_fs=6.4, title_dy=3.0)
    route(ax, [(150, 12), (126, 12)], C_AXARR_EDGE, lw=1.6)
    note(ax, 70, 12, "AXI GPIO per pipeline: camera GPIO + resets of Demosaic, Gamma LUT,\n"
         "VPSS, Frame Buffer Write and Frame Buffer Read.  Video clock 300 MHz.", fs=6.6)
    save(fig, "rpi-camera-fmc-simple-pipeline.png")


# ---- 6. display pipeline, MicroBlaze (AUBoard) ----------------------------------
def fig_hdmi_display():
    fig, ax = new_fig(17.0, 5.8, 170, 58)
    container(ax, 22, 2, 100, 50, C_FAB_FILL, C_FAB_EDGE,
              "Display pipeline  (AUBoard 15P, MicroBlaze design)")
    container(ax, 128, 2, 40, 50, C_FMC_FILL, C_FMC_EDGE, "On the board")
    titled_box(ax, 2, 6, 16, 40, C_PS_FILL, C_PS_EDGE, "DDR4",
               "camera\nframe\nbuffers", title_fs=8.6, body_fs=6.8)
    titled_box(ax, 26, 34, 18, 12, C_IP_FILL, C_IP_EDGE, "Test Pattern\nGenerator",
               "mixer master layer", title_fs=7.6, body_fs=6.4, title_dy=3.0)
    titled_box(ax, 26, 18, 18, 12, C_IP_FILL, C_IP_EDGE, "Frame Buffer\nRead (CAM0)",
               "", title_fs=7.6, title_dy=4.0)
    titled_box(ax, 26, 4, 18, 12, C_IP_FILL, C_IP_EDGE, "Frame Buffer\nRead (CAM2)",
               "", title_fs=7.6, title_dy=4.0)
    harrow(ax, 18, 26, 24, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=1.0, hh=1.9, hl=1.4)
    harrow(ax, 18, 26, 10, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=1.0, hh=1.9, hl=1.4)
    titled_box(ax, 50, 8, 18, 38, C_IP_FILL, C_IP_EDGE, "Video Mixer",
               "master: TPG\nlayers: one\nAXI4-Stream\ninput per\ncamera\n\n"
               "1920 x 1080\n2 pixels/clock", title_fs=8.2, body_fs=6.6)
    for y in (40, 24, 10):
        harrow(ax, 44, 50, y, bh=0.9, hh=1.7, hl=1.3)
    titled_box(ax, 74, 17, 20, 20, C_IP_FILL, C_IP_EDGE, "HDMI TX\nSubsystem",
               "8 bpc\n(licensed IP)", title_fs=8.0, body_fs=6.6, title_dy=3.4)
    harrow(ax, 68, 74, 27, bh=1.0, hh=1.9, hl=1.4)
    titled_box(ax, 100, 17, 20, 20, C_HARD_FILL, C_HARD_EDGE, "Video PHY\nController",
               "GTHE4\n5.94 Gb/s max\nref 297 MHz", title_fs=8.0, body_fs=6.6,
               title_dy=3.4)
    harrow(ax, 94, 100, 27, bh=1.0, hh=1.9, hl=1.4)
    titled_box(ax, 131, 34, 34, 14, C_CLK_FILL, C_CLK_EDGE, "IDT 8T49N241",
               "HDMI TX reference clock\n(programmed over I2C by the MicroBlaze)",
               title_fs=7.6, body_fs=6.4, title_dy=2.4)
    route(ax, [(131, 41), (110, 41), (110, 37)], C_REFCLK_LINE)
    titled_box(ax, 148, 8, 17, 20, C_EXT_FILL, C_FMC_EDGE, "HDMI\nmonitor",
               "1080p", title_fs=8.2, body_fs=6.6, title_dy=3.4)
    harrow(ax, 120, 148, 20, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, bh=1.0, hh=1.9,
           hl=1.4)
    note(ax, 134, 23, "TMDS", fs=6.4)
    save(fig, "rpi-camera-fmc-hdmi-display-pipe.png")


# ---- 7. Versal display pipeline (DVI over HDMI, free IP only) ----------------
def fig_versal_dvi_display():
    fig, ax = new_fig(19.0, 7.4, 190, 74)
    container(ax, 2, 2, 20, 62, C_PS_FILL, C_PS_EDGE, "CIPS + NoC")
    container(ax, 26, 2, 116, 62, C_FAB_FILL, C_FAB_EDGE,
              "display_pipeline + video_output  (PL, Versal designs)")
    container(ax, 146, 2, 42, 62, C_FMC_FILL, C_FMC_EDGE, "On the board")

    # CIPS / NoC
    titled_box(ax, 4, 34, 16, 22, "#EAEAEA", C_PS_EDGE, "NoC → DDR",
               "camera\nframe\nbuffers", title_fs=8.0, body_fs=6.6)
    titled_box(ax, 4, 6, 16, 22, "#EAEAEA", C_PS_EDGE, "AXI-Lite\ncontrol",
               "M_AXI_FPD:\nmixer\nM_AXI_LPD:\nVTC, IIC,\nGPIO", title_fs=7.6,
               body_fs=6.2, title_dy=3.4)

    # mixer + timing
    titled_box(ax, 30, 26, 20, 32, C_IP_FILL, C_IP_EDGE, "Video Mixer",
               "\nlayers 1-4: YUYV\n(one per camera)\nlayer 5: RGBA\n\nout: RGB 8 bpc\n"
               "1920 x 1080\nbackground: blue", title_fs=8.6, body_fs=6.4)
    harrow(ax, 20, 30, 45, fc=C_AXARR_FILL, ec=C_AXARR_EDGE, bh=1.0, hh=1.9, hl=1.4)
    titled_box(ax, 30, 6, 20, 14, C_IP_FILL, C_IP_EDGE, "Video Timing\nController",
               "1080p60 timing", title_fs=7.6, body_fs=6.4, title_dy=3.4)
    titled_box(ax, 56, 32, 18, 16, C_IP_FILL, C_IP_EDGE, "AXI4-Stream\nto Video Out",
               "VTG slave", title_fs=7.6, body_fs=6.4, title_dy=3.4)
    harrow(ax, 50, 56, 40, bh=1.0, hh=1.9, hl=1.3)
    route(ax, [(50, 13), (53, 13), (53, 36), (56, 36)], C_CTRL_LINE)
    note(ax, 53, 24.5, "timing", fs=6.2, color=C_CTRL_LINE, rot=90)

    # DVI encoder, gearbox, transceivers
    titled_box(ax, 80, 30, 20, 20, C_IP_FILL, C_IP_EDGE, "DVI TMDS\nencoder",
               "3x 8b/10b (DVI 1.0)\ncolour-bar test\npattern\n(open-source RTL)",
               title_fs=7.6, body_fs=6.2, title_dy=3.4)
    harrow(ax, 74, 80, 40, bh=1.0, hh=1.9, hl=1.3)
    note(ax, 77, 45.5, "RGB +\nDE/HS/VS", fs=6.0)
    titled_box(ax, 104, 30, 16, 20, C_IP_FILL, C_IP_EDGE, "TX gearbox",
               "async FIFO\n10 bit @148.5 MHz\n→ 20 bit\n@74.25 MHz",
               title_fs=7.6, body_fs=6.0)
    harrow(ax, 100, 104, 40, bh=1.0, hh=1.9, hl=1.1)
    titled_box(ax, 123, 24, 17, 32, C_HARD_FILL, C_HARD_EDGE, "Transceivers",
               "gtwiz_versal\nTX only, 4 lanes\n1.485 Gb/s\nlanes 0-2: TMDS\ndata\n"
               "lane 3: TMDS\nclock\n\nVCK190: GTY\nVEK280: GTYP", title_fs=7.6,
               body_fs=5.9)
    harrow(ax, 120, 123, 40, bh=1.0, hh=1.9, hl=1.0)

    # control IP
    titled_box(ax, 56, 6, 18, 14, C_CTRL_FILL, C_CTRL_EDGE, "AXI GPIO",
               "DVI status and\ncontrol (dvi-status)", title_fs=7.6, body_fs=6.0)
    route(ax, [(74, 13), (90, 13), (90, 30)], C_CTRL_LINE)
    titled_box(ax, 100, 6, 18, 14, C_CTRL_FILL, C_CTRL_EDGE, "AXI IIC",
               "HDMI control\nI2C bus", title_fs=7.6, body_fs=6.0)
    route(ax, [(118, 13), (157, 13), (157, 18)], C_CTRL_LINE)
    route(ax, [(144, 13), (144, 60), (149, 60)], C_CTRL_LINE)
    note(ax, 131, 10.6, "I2C", fs=6.2, color=C_CTRL_LINE)

    # board side
    titled_box(ax, 149, 50, 18, 12, C_CLK_FILL, C_CLK_EDGE, "8T49N241",
               "clock synthesiser\n148.5 MHz (Linux)", title_fs=7.6, body_fs=6.0)
    route(ax, [(149, 54), (140, 54)], C_REFCLK_LINE)
    note(ax, 144.5, 51.8, "refclk", fs=6.0, color=C_REFCLK_LINE)
    note(ax, 131.5, 20.6, "pixel clock = refclk\n148.5 MHz → VTC, video out,\nencoder",
         fs=5.9, color=C_REFCLK_LINE)
    titled_box(ax, 149, 18, 18, 18, C_HARD_FILL, C_HARD_EDGE, "Retimer /\nredriver",
               "VCK190: SN65DP159\nVEK280: TMDS1204\n(set up by dvi-init)",
               title_fs=7.6, body_fs=5.9, title_dy=3.4)
    harrow(ax, 140, 149, 30, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, bh=1.0, hh=1.9,
           hl=1.2)
    titled_box(ax, 171, 18, 15, 18, C_EXT_FILL, C_FMC_EDGE, "HDMI TX\nconnector",
               "→ HDMI\nmonitor\n1080p60\n(DVI mode)", title_fs=7.4, body_fs=6.0,
               title_dy=3.4)
    harrow(ax, 167, 171, 27, fc=C_LINKARR_FILL, ec=C_LINKARR_EDGE, bh=1.0, hh=1.9,
           hl=1.1)
    save(fig, "rpi-camera-fmc-versal-dvi-display.png")


def main():
    fig_architecture()
    fig_mipi_pipeline()
    fig_display_pipeline()
    fig_end_to_end()
    fig_simple_pipeline()
    fig_hdmi_display()
    fig_versal_dvi_display()


if __name__ == "__main__":
    main()
