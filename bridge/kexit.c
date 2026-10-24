// kexit: the way out of the Omarchy session. Runs on the Kindle host, outside the chroot.
// It grabs the power key so powerd cannot suspend the device under a paused framework, and a press
// ends the session. It also ends the session when Hyprland is gone, so the Kindle UI always comes back.
#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define POWER_KEY "/dev/input/event0"
#define STOP "/mnt/base-us/omarchy/bin/session.sh"

static int process_running(const char *comm) {
	DIR *proc = opendir("/proc");
	struct dirent *e;
	char path[300], name[32];
	int found = 0;
	while (!found && (e = readdir(proc))) {
		if (e->d_name[0] < '0' || e->d_name[0] > '9')
			continue;
		snprintf(path, sizeof path, "/proc/%s/comm", e->d_name);
		FILE *f = fopen(path, "r");
		if (f && fgets(name, sizeof name, f))
			found = strncmp(name, comm, strlen(comm)) == 0 && name[strlen(comm)] == '\n';
		if (f)
			fclose(f);
	}
	closedir(proc);
	return found;
}

static void end_session(const char *why) {
	fprintf(stderr, "kexit: %s, stopping the session\n", why);
	execl("/bin/sh", "sh", STOP, "stop", (char *)NULL);
	perror("kexit: exec");
	_exit(1);
}

int main(void) {
	int fd = open(POWER_KEY, O_RDONLY);
	if (fd < 0 || ioctl(fd, EVIOCGRAB, 1) < 0) {
		perror("kexit: " POWER_KEY);
		return 1;
	}
	struct pollfd p = { .fd = fd, .events = POLLIN };
	int missing = 0;
	for (;;) {
		if (poll(&p, 1, 5000) > 0) {
			struct input_event ev;
			if (read(fd, &ev, sizeof ev) == sizeof ev && ev.type == EV_KEY && ev.code == KEY_POWER && ev.value == 1) {
				close(fd);
				end_session("power key");
			}
			continue;
		}
		// start-hyprland restarts a crashed Hyprland, so only a gap seen twice in a row counts.
		missing = process_running("Hyprland") ? 0 : missing + 1;
		if (missing >= 2) {
			close(fd);
			end_session("Hyprland is gone");
		}
	}
}
