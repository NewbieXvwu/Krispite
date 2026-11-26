package com.krispite;

import java.util.Locale;
import org.lwjgl.system.Configuration;

/** Loader-agnostic early setup: extracts native Vulkan libraries and redirects LWJGL. */
public final class KrispiteEarlySetup {

    private KrispiteEarlySetup() {
    }

    public static boolean isMac() {
        return System.getProperty("os.name", "").toLowerCase(Locale.ROOT).contains("mac");
    }

    /** Called once, right before Minecraft loads the Vulkan loader. */
    public static void init() {
        if (!isMac()) {
            KrispiteLog.warn("prelaunch.skipped_os");
            return;
        }

        try {
            NativeExtractor.extract();
            NativeExtractor.writeIcdJson();
            NativeExtractor.removeLegacyIcdJson();
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
