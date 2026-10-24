// Firefox on the Kindle shares 970 MB with Hyprland and the Omarchy shell.
// One content process and no site isolation are the bulk of the saving.
pref("fission.autostart", false);
pref("dom.ipc.processCount", 1);
pref("dom.ipc.processCount.webIsolated", 1);
pref("dom.ipc.processPrelaunch.enabled", false);
pref("browser.cache.memory.capacity", 16384);
pref("browser.sessionhistory.max_total_viewers", 0);
pref("browser.newtabpage.enabled", false);
pref("browser.startup.page", 0);
pref("browser.shell.checkDefaultBrowser", false);
pref("extensions.pocket.enabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("toolkit.telemetry.enabled", false);
pref("app.normandy.enabled", false);
pref("network.prefetch-next", false);
pref("network.http.speculative-parallel-limit", 0);
pref("extensions.webextensions.remote", false);
pref("browser.sessionstore.resume_from_crash", false);
