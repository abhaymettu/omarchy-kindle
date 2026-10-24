// gbmprobe: the allocation path Aquamarine/Hyprland take, on an explicit DRM node.
// Opens the node, creates a GBM device and a 1072x1448 XRGB8888 buffer, initialises EGL on
// that GBM device, renders a clear into a GBM surface and reads one pixel back.
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <fcntl.h>
#include <gbm.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <xf86drm.h>

#define W 1072
#define H 1448

static int fail(const char *what) {
	fprintf(stderr, "FAIL %s (egl=0x%x)\n", what, eglGetError());
	return 1;
}

int main(int argc, char **argv) {
	const char *node = argc > 1 ? argv[1] : "/dev/dri/card0";
	int fd = open(node, O_RDWR | O_CLOEXEC);
	if (fd < 0)
		return fail("open");
	drmVersionPtr v = drmGetVersion(fd);
	printf("node %s driver %s\n", node, v ? v->name : "?");

	struct gbm_device *gbm = gbm_create_device(fd);
	if (!gbm)
		return fail("gbm_create_device");
	printf("gbm backend %s\n", gbm_device_get_backend_name(gbm));

	struct gbm_bo *bo = gbm_bo_create(gbm, W, H, GBM_FORMAT_XRGB8888, GBM_BO_USE_RENDERING | GBM_BO_USE_LINEAR);
	if (!bo)
		return fail("gbm_bo_create");
	int prime = gbm_bo_get_fd(bo);
	printf("bo %ux%u stride %u prime_fd %d\n", gbm_bo_get_width(bo), gbm_bo_get_height(bo), gbm_bo_get_stride(bo), prime);

	int fd2 = open(node, O_RDWR | O_CLOEXEC);
	struct gbm_device *gbm2 = gbm_create_device(fd2);
	EGLDisplay dpy = eglGetPlatformDisplay(EGL_PLATFORM_GBM_KHR, gbm2, NULL);
	EGLint major, minor;
	if (!eglInitialize(dpy, &major, &minor))
		return fail("eglInitialize");
	eglBindAPI(EGL_OPENGL_ES_API);
	EGLint cfg_attrs[] = { EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
		EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_NONE };
	EGLConfig cfgs[64];
	EGLint n = 0;
	eglChooseConfig(dpy, cfg_attrs, cfgs, 64, &n);
	EGLConfig cfg = NULL;
	for (int i = 0; i < n && !cfg; i++) {
		EGLint id;
		eglGetConfigAttrib(dpy, cfgs[i], EGL_NATIVE_VISUAL_ID, &id);
		if (id == GBM_FORMAT_XRGB8888)
			cfg = cfgs[i];
	}
	if (!cfg)
		return fail("no XRGB8888 config");
	struct gbm_surface *gs = gbm_surface_create(gbm2, W, H, GBM_FORMAT_XRGB8888, GBM_BO_USE_RENDERING);
	if (!gs)
		return fail("gbm_surface_create");
	EGLSurface surf = eglCreatePlatformWindowSurface(dpy, cfg, gs, NULL);
	EGLint ctx_attrs[] = { EGL_CONTEXT_MAJOR_VERSION, 3, EGL_NONE };
	EGLContext ctx = eglCreateContext(dpy, cfg, EGL_NO_CONTEXT, ctx_attrs);
	if (surf == EGL_NO_SURFACE || ctx == EGL_NO_CONTEXT || !eglMakeCurrent(dpy, surf, surf, ctx))
		return fail("surface/context");
	printf("EGL %d.%d renderer %s, %s\n", major, minor, glGetString(GL_RENDERER), glGetString(GL_VERSION));

	PFNEGLCREATEIMAGEKHRPROC create_image = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
	EGLint img_attrs[] = { EGL_WIDTH, W, EGL_HEIGHT, H, EGL_LINUX_DRM_FOURCC_EXT, GBM_FORMAT_XRGB8888,
		EGL_DMA_BUF_PLANE0_FD_EXT, prime, EGL_DMA_BUF_PLANE0_OFFSET_EXT, 0,
		EGL_DMA_BUF_PLANE0_PITCH_EXT, (EGLint)gbm_bo_get_stride(bo),
		EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, 0, EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, 0, EGL_NONE };
	EGLImageKHR img = create_image(dpy, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, img_attrs);
	printf("dmabuf import on second fd, LINEAR modifier: %s (egl 0x%x)\n", img != EGL_NO_IMAGE_KHR ? "ok" : "FAILED", eglGetError());

	GLuint tex, fbo;
	unsigned char fpx[4] = { 0 };
	glGenTextures(1, &tex);
	glBindTexture(GL_TEXTURE_2D, tex);
	glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, 16, 16);
	glGenFramebuffers(1, &fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, fbo);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
	glClearColor(0.25f, 0.5f, 0.75f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
	glReadPixels(8, 8, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, fpx);
	printf("offscreen fbo pixel %u %u %u\n", fpx[0], fpx[1], fpx[2]);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	EGLint draw_buf = 0;
	glGetIntegerv(GL_DRAW_BUFFER0, &draw_buf);
	glClear(GL_COLOR_BUFFER_BIT);
	glFinish();
	unsigned char px[4] = { 0 };
	glReadPixels(W / 2, H / 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
	printf("window draw buffer 0x%x gl error 0x%x\n", draw_buf, glGetError());
	if (!eglSwapBuffers(dpy, surf))
		return fail("eglSwapBuffers");
	struct gbm_bo *front = gbm_surface_lock_front_buffer(gs);
	printf("pixel %u %u %u, front bo %s\n", px[0], px[1], px[2], front ? "locked" : "MISSING");
	if (front) {
		uint32_t stride;
		void *map_data = NULL;
		uint8_t *m = gbm_bo_map(front, 0, 0, W, H, GBM_BO_TRANSFER_READ, &stride, &map_data);
		if (m) {
			uint8_t *c = m + (size_t)(H / 2) * stride + (W / 2) * 4;
			printf("front bo mapped stride %u pixel BGRX %u %u %u\n", stride, c[0], c[1], c[2]);
			gbm_bo_unmap(front, map_data);
		} else {
			printf("front bo map FAILED\n");
		}
	}
	printf(front && px[0] == 64 && px[1] == 128 && px[2] == 191 ? "PASS\n" : "FAIL readback\n");
	return 0;
}
