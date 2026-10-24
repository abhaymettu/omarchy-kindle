// Preloaded into Quickshell on the 4.9 kernel, which has no pidfd (Linux 5.4), so Qt's forkfd reaps
// children through a SIGCHLD handler it installs once per process. QProcess::startDetached reaches that
// one-time setup inside its vfork child: the child marks it done in the shared memory and installs the
// handler only in itself. Every later QProcess in the shell then never hears its child exit.
// Running one ordinary process when the application starts installs the handler in the shell itself. The preload is then
// dropped so the shell's own children do not each load QtCore.
#include <QCoreApplication>
#include <QProcess>
#include <stdlib.h>

static void install_sigchld_handler() {
	QProcess::execute(QStringLiteral("/usr/bin/true"), {});
	unsetenv("LD_PRELOAD");
}
Q_COREAPP_STARTUP_FUNCTION(install_sigchld_handler)
