package com.krispite;

import net.fabricmc.loader.api.entrypoint.PreLaunchEntrypoint;

/** Runs before Minecraft's rendering classes have a chance to load LWJGL Vulkan. */
public final class PreLaunchSetup implements PreLaunchEntrypoint {

    @Override
    public void onPreLaunch() {
        if (!System.getProperty("os.name", "").toLowerCase(java.util.Locale.ROOT).contains("mac")) {
            KrispiteLog.warn("prelaunch.skipped_os");
            return;
        }

        try {
            NativeExtractor.extract();
            NativeExtractor.writeIcdJson();
            String loaderPath = NativeExtractor.vulkanLoaderPath().toAbsolutePath().toString();
            String previous = System.setProperty("org.lwjgl.vulkan.libname", loaderPath);
            KrispiteLog.info("prelaunch.complete", loaderPath, NativeExtractor.readBundledVersionDetail());
            if (previous != null && !previous.equals(loaderPath)) {
                KrispiteLog.info("prelaunch.replaced_loader", previous);
            }
        } catch (Exception exception) {
            KrispiteLog.error("prelaunch.failed", exception);
        }
    }
}
