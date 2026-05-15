FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " file://bsp.cfg"
KERNEL_FEATURES:append = " bsp.cfg"

# Workaround for NULL deref in xlnx_mix_connector_init when
# xlnx_mixer.connect_drm_bridge=1 is set (needed for 2025.2 v_mix->dpsub
# DRM-bridge pipeline; dpsub no longer registers as an xlnx_bridge).
SRC_URI:append = " file://0001-drm-xlnx-mixer-fix-NULL-deref-in-connector_init.patch"

# Drop manual drm_mode_config_cleanup() in xlnx_unbind; required since the
# v_mix bridge-connector path uses drm_managed-based init helpers that
# clash with the manual cleanup (double-cleanup → ida_free for unallocated
# id and NULL deref during poweroff / reboot).
SRC_URI:append = " file://0002-drm-xlnx-drv-drop-mode_config_cleanup-on-unbind.patch"

# Silence drm_vblank_init_release WARN_ON on shutdown by powering outputs
# down via drm_atomic_helper_shutdown() before drm_dev_unregister().
SRC_URI:append = " file://0003-drm-xlnx-drv-disable-vblank-before-cleanup-on-shutdown.patch"
