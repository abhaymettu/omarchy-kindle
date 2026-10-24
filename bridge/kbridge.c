// kbridge: mirror a Wayland output onto the Kindle e-ink panel.
// Damage-driven: wlr-screencopy copy_with_damage only completes when the output changed,
// so an idle desktop costs nothing. Damaged rects are converted to Y8 and pushed with FBInk.
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>

#include "fbink.h"
#include "wlr-screencopy-unstable-v1-client-protocol.h"

#define MAX_RECTS 64
#define FULL_FLASH_EVERY 30

struct rect { int x, y, w, h; };

static struct {
	struct wl_shm *shm;
	struct wl_output *output;
	struct zwlr_screencopy_manager_v1 *copier;

	struct wl_buffer *buffer;
	uint8_t *pixels;
	uint32_t format, width, height, stride;

	struct rect damage[MAX_RECTS];
	int ndamage;
	int done, failed;

	uint8_t *gray;
	int fbfd;
	FBInkConfig cfg;
	unsigned updates;
} s;

static void on_global(void *data, struct wl_registry *reg, uint32_t name, const char *iface, uint32_t version) {
	if (!strcmp(iface, wl_shm_interface.name))
		s.shm = wl_registry_bind(reg, name, &wl_shm_interface, 1);
	else if (!strcmp(iface, wl_output_interface.name) && !s.output)
		s.output = wl_registry_bind(reg, name, &wl_output_interface, 1);
	else if (!strcmp(iface, zwlr_screencopy_manager_v1_interface.name))
		s.copier = wl_registry_bind(reg, name, &zwlr_screencopy_manager_v1_interface, version < 3 ? version : 3);
}
static void on_global_remove(void *data, struct wl_registry *reg, uint32_t name) {}
static const struct wl_registry_listener registry_listener = { on_global, on_global_remove };

static int create_shm_buffer(void) {
	size_t size = (size_t)s.stride * s.height;
	int fd = memfd_create("kbridge", MFD_CLOEXEC);
	if (fd < 0 || ftruncate(fd, size) < 0)
		return -1;
	s.pixels = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (s.pixels == MAP_FAILED)
		return -1;
	struct wl_shm_pool *pool = wl_shm_create_pool(s.shm, fd, size);
	s.buffer = wl_shm_pool_create_buffer(pool, 0, s.width, s.height, s.stride, s.format);
	wl_shm_pool_destroy(pool);
	close(fd);
	s.gray = malloc((size_t)s.width * s.height);
	return s.gray ? 0 : -1;
}

static void on_buffer(void *data, struct zwlr_screencopy_frame_v1 *frame, uint32_t format, uint32_t w, uint32_t h, uint32_t stride) {
	if (s.buffer)
		return;
	s.format = format, s.width = w, s.height = h, s.stride = stride;
	if (create_shm_buffer() < 0) {
		perror("kbridge: shm buffer");
		exit(1);
	}
}
static void on_flags(void *data, struct zwlr_screencopy_frame_v1 *frame, uint32_t flags) {}
static void on_damage(void *data, struct zwlr_screencopy_frame_v1 *frame, uint32_t x, uint32_t y, uint32_t w, uint32_t h) {
	if (s.ndamage < MAX_RECTS)
		s.damage[s.ndamage++] = (struct rect){ x, y, w, h };
	else
		s.damage[0] = (struct rect){ 0, 0, s.width, s.height }, s.ndamage = 1;
}
static void on_buffer_done(void *data, struct zwlr_screencopy_frame_v1 *frame) {
	zwlr_screencopy_frame_v1_copy_with_damage(frame, s.buffer);
}
static void on_ready(void *data, struct zwlr_screencopy_frame_v1 *frame, uint32_t sec_hi, uint32_t sec_lo, uint32_t nsec) { s.done = 1; }
static void on_failed(void *data, struct zwlr_screencopy_frame_v1 *frame) { s.failed = 1; }
static void on_linux_dmabuf(void *data, struct zwlr_screencopy_frame_v1 *frame, uint32_t format, uint32_t w, uint32_t h) {}

static const struct zwlr_screencopy_frame_v1_listener frame_listener = {
	.buffer = on_buffer,
	.flags = on_flags,
	.ready = on_ready,
	.failed = on_failed,
	.damage = on_damage,
	.linux_dmabuf = on_linux_dmabuf,
	.buffer_done = on_buffer_done,
};

// XRGB8888/ARGB8888 are B,G,R,X in memory; XBGR8888/ABGR8888 are R,G,B,X.
static void to_gray(struct rect r) {
	int bgr = s.format == WL_SHM_FORMAT_XRGB8888 || s.format == WL_SHM_FORMAT_ARGB8888;
	for (int y = 0; y < r.h; y++) {
		const uint8_t *src = s.pixels + (size_t)(r.y + y) * s.stride + (size_t)r.x * 4;
		uint8_t *dst = s.gray + (size_t)y * r.w;
		for (int x = 0; x < r.w; x++, src += 4) {
			unsigned R = bgr ? src[2] : src[0], G = src[1], B = bgr ? src[0] : src[2];
			dst[x] = (uint8_t)((R * 77 + G * 151 + B * 28) >> 8);
		}
	}
}

static void push(struct rect r, bool flash) {
	if (r.w <= 0 || r.h <= 0)
		return;
	to_gray(r);
	s.cfg.is_flashing = flash || ++s.updates % FULL_FLASH_EVERY == 0;
	if (fbink_print_raw_data(s.fbfd, s.gray, r.w, r.h, (size_t)r.w * r.h, r.x, r.y, &s.cfg) < 0)
		fprintf(stderr, "kbridge: fbink_print_raw_data failed for %dx%d+%d+%d\n", r.w, r.h, r.x, r.y);
}

// Merge all damage into one bounding box: one e-ink refresh beats many small ones.
static struct rect bounding_box(void) {
	int x0 = s.width, y0 = s.height, x1 = 0, y1 = 0;
	for (int i = 0; i < s.ndamage; i++) {
		struct rect d = s.damage[i];
		if (d.x < x0) x0 = d.x;
		if (d.y < y0) y0 = d.y;
		if (d.x + d.w > x1) x1 = d.x + d.w;
		if (d.y + d.h > y1) y1 = d.y + d.h;
	}
	if (x1 > (int)s.width) x1 = s.width;
	if (y1 > (int)s.height) y1 = s.height;
	return (struct rect){ x0, y0, x1 - x0, y1 - y0 };
}

int main(void) {
	struct wl_display *display = wl_display_connect(NULL);
	if (!display) {
		fprintf(stderr, "kbridge: cannot connect to Wayland display\n");
		return 1;
	}
	struct wl_registry *registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	if (!s.shm || !s.output || !s.copier) {
		fprintf(stderr, "kbridge: missing wl_shm, wl_output or wlr-screencopy\n");
		return 1;
	}

	s.fbfd = fbink_open();
	if (s.fbfd < 0 || fbink_init(s.fbfd, &s.cfg) < 0) {
		fprintf(stderr, "kbridge: FBInk init failed\n");
		return 1;
	}
	s.cfg.wfm_mode = WFM_AUTO;
	s.cfg.is_quiet = true;

	int first = 1;
	while (1) {
		s.done = s.failed = 0;
		s.ndamage = 0;
		struct zwlr_screencopy_frame_v1 *frame = zwlr_screencopy_manager_v1_capture_output(s.copier, 0, s.output);
		zwlr_screencopy_frame_v1_add_listener(frame, &frame_listener, NULL);
		while (!s.done && !s.failed)
			if (wl_display_dispatch(display) < 0)
				return 1;
		zwlr_screencopy_frame_v1_destroy(frame);
		if (s.failed) {
			fprintf(stderr, "kbridge: frame capture failed\n");
			return 1;
		}
		if (first || s.ndamage == 0)
			push((struct rect){ 0, 0, s.width, s.height }, true);
		else
			push(bounding_box(), false);
		first = 0;
	}
}
