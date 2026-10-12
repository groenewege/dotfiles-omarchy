# Installed by dotfiles (scripts/05-hardware.sh) on MacBookPro16,1.
# Sourced by uwsm (POSIX sh) before Hyprland starts.
#
# Hyprland renders on the Intel GPU, which has the panel (apple_gmux.force_igd),
# even when the AMD GPU happens to be ready first. Only set when the Intel GPU
# really has the panel, so a boot entry without force_igd still gets a picture.
# (Aquamarine still adds the AMD GPU when it appears later; monitors.lua
# switches off its phantom eDP-2.)
#
# The external display ports are wired to the AMD GPU. To use an external
# monitor, add a udev symlink for 0000:03:00.0 (see gpu.rules) and list it
# second: AQ_DRM_DEVICES=/dev/dri/intel-igpu:/dev/dri/amd-dgpu
for __dotfiles_status__ in /sys/bus/pci/devices/0000:00:02.0/drm/card*/card*-eDP-*/status; do
	if [ -e /dev/dri/intel-igpu ] && [ "$(cat "$__dotfiles_status__" 2>/dev/null)" = connected ]; then
		export AQ_DRM_DEVICES=/dev/dri/intel-igpu
	fi
done
unset __dotfiles_status__
