// udevprobe: the exact udev enumeration Aquamarine's DRM backend performs.
#include <libudev.h>
#include <stdio.h>
#include <string.h>

int main(void) {
	struct udev *u = udev_new();
	struct udev_enumerate *e = udev_enumerate_new(u);
	udev_enumerate_add_match_subsystem(e, "drm");
	udev_enumerate_add_match_property(e, "DEVTYPE", "drm_minor");
	udev_enumerate_add_match_sysname(e, "card[0-9]*");
	int r = udev_enumerate_scan_devices(e);
	printf("scan_devices=%d (%s)\n", r, r < 0 ? strerror(-r) : "ok");
	struct udev_list_entry *it;
	udev_list_entry_foreach(it, udev_enumerate_get_list_entry(e)) {
		struct udev_device *d = udev_device_new_from_syspath(u, udev_list_entry_get_name(it));
		printf("device %s devnode %s\n", udev_list_entry_get_name(it), d ? udev_device_get_devnode(d) : "?");
	}
	return 0;
}
