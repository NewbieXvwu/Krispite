package com.krispite.mixin;

import com.krispite.KrispiteLog;
import net.minecraft.client.Minecraft;
import net.minecraft.client.OptionInstance;
import net.minecraft.client.PreferredGraphicsApi;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyArg;

@Mixin(Minecraft.class)
abstract class MinecraftMixin {

    @ModifyArg(
        method = "<init>",
        at = @At(
            value = "INVOKE",
            target = "Lnet/minecraft/client/OptionInstance;set(Ljava/lang/Object;)V",
            ordinal = 0
        ),
        index = 0
    )
    private Object krispite$keepVulkanAfterCrashRecovery(Object requestedBackend) {
        if (!System.getProperty("os.name", "").toLowerCase(java.util.Locale.ROOT).contains("mac")) {
            return requestedBackend;
        }
        // Minecraft resets Vulkan to Default after an unclean exit.  Keep the
        // requested backend so the following startup still exercises KosmicKrisp.
        KrispiteLog.info("options.locked_vulkan");
        return PreferredGraphicsApi.VULKAN;
    }
}
