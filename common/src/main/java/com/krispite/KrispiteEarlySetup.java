package com.krispite;

import org.lwjgl.system.Configuration;

/** Loader-agnostic early setup: extracts native Vulkan libraries and redirects LWJGL. */
public final class KrispiteEarlySetup {

    private KrispiteEarlySetup() {
    }

    public static void init() {
        if (!System.getProperty("os.name", "").toLowerCase(java.util.Locale.ROOT).contains("mac")) {
            KrispiteLog.warn("prelaunch.skipped_os");
            return;
        }

        try {
            NativeExtractor.extract();
            NativeExtractor.writeIcdJson();
            NativeExtractor.configureVulkanDriver();
            String loaderPath = NativeExtractor.vulkanLoaderPath().toAbsolutePath().toString();
            String previous = Configuration.VULKAN_LIBRARY_NAME.get();
            Configuration.VULKAN_LIBRARY_NAME.set(loaderPath);
            System.setProperty("org.lwjgl.vulkan.libname", loaderPath);
            KrispiteLog.info("prelaunch.complete", loaderPath, NativeExtractor.readBundledVersionDetail());
            if (previous != null && !previous.equals(loaderPath)) {
                KrispiteLog.info("prelaunch.replaced_loader", previous);
            }
        } catch (Exception exception) {
            KrispiteLog.error("prelaunch.failed", exception);
        }
    }
}
