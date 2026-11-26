package com.krispite.mixin;

import com.krispite.KrispiteEarlySetup;
import com.krispite.KrispiteLog;
import net.minecraft.client.Minecraft;
import net.minecraft.client.PreferredGraphicsApi;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyArg;

@Mixin(Minecraft.class)
abstract class MinecraftMixin {

    // No ordinal: the constructor calls OptionInstance#set for several options
    // (since 26.3 the fullscreen reset comes first), so match all of them and
    // only rewrite the graphics backend ones.
    @ModifyArg(
        method = "<init>",
        at = @At(
            value = "INVOKE",
            target = "Lnet/minecraft/client/OptionInstance;set(Ljava/lang/Object;)V"
        ),
        index = 0
    )
    private Object krispite$keepVulkanAfterCrashRecovery(Object requestedValue) {
        if (!(requestedValue instanceof PreferredGraphicsApi)
                || !KrispiteEarlySetup.isMac()) {
            return requestedValue;
        }
        // Minecraft resets Vulkan to Default (and then OpenGL) after an unclean exit.
        // Keep Vulkan so the following startup still exercises KosmicKrisp.
        KrispiteLog.info("options.locked_vulkan");
        return PreferredGraphicsApi.VULKAN;
    }
}
