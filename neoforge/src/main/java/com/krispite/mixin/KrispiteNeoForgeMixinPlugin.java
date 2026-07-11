package com.krispite.mixin;

import java.util.List;
import java.util.Set;

import org.objectweb.asm.tree.ClassNode;
import org.spongepowered.asm.mixin.extensibility.IMixinConfigPlugin;
import org.spongepowered.asm.mixin.extensibility.IMixinInfo;

import com.krispite.KrispiteLog;

/**
 * Conditionally applies {@link WindowMixin} based on whether the running NeoForge already
 * ships the ELS (Early Loading Screen) renderer abstraction (upstream PR #3259 +
 * FancyModLoader #430). That fix removes the GL-window takeover that conflicts with a Vulkan
 * (NO_API) window, so the workaround is unnecessary there.
 *
 * <p>We detect the fix by the <em>presence of its marker classes</em> rather than a version
 * string, which is robust against beta/PR build numbers and against not knowing when the fix
 * lands on a given 26.2.x line. The marker classes ({@code earlydisplay.Blaze3D*}) exist only
 * in fixed builds — verified absent in 26.2.0.8-beta and present on the els_backend branch.
 */
public final class KrispiteNeoForgeMixinPlugin implements IMixinConfigPlugin {

    private static final String WINDOW_MIXIN = "com.krispite.mixin.WindowMixin";

    // Classes introduced exclusively by the ELS renderer abstraction fix. Probing a small set
    // reduces the chance a single rename (PR -> mainline) slips through undetected.
    private static final String[] FIX_MARKERS = {
        "net.neoforged.neoforge.client.loading.earlydisplay.Blaze3DRenderBackend",
        "net.neoforged.neoforge.client.loading.earlydisplay.Blaze3DConst"
    };

    private final boolean fixPresent = probeFix();
    private boolean logged;

    private static boolean probeFix() {
        for (String name : FIX_MARKERS) {
            try {
                Class.forName(name);
                return true;
            } catch (Throwable ignored) {
                // Class absent on this build; keep probing.
            }
        }
        return false;
    }

    @Override
    public void onLoad(String mixinPackage) {
    }

    @Override
    public String getRefMapperConfig() {
        return null;
    }

    @Override
    public boolean shouldApplyMixin(String targetClassName, String mixinClassName) {
        if (WINDOW_MIXIN.equals(mixinClassName)) {
            if (!logged) {
                logged = true;
                if (fixPresent) {
                    KrispiteLog.info("neoforge.els_fix_detected");
                } else {
                    KrispiteLog.info("neoforge.els_fix_absent");
                }
            }
            // Apply the Vulkan early-display workaround only when the fix is absent.
            return !fixPresent;
        }
        return true;
    }

    @Override
    public void acceptTargets(Set<String> myTargets, Set<String> otherTargets) {
    }

    @Override
    public List<String> getMixins() {
        return null;
    }

    @Override
    public void preApply(String targetClassName, ClassNode targetClass, String mixinClassName, IMixinInfo mixinInfo) {
    }

    @Override
    public void postApply(String targetClassName, ClassNode targetClass, String mixinClassName, IMixinInfo mixinInfo) {
    }
}
