package com.krispite.mixin;

import com.krispite.KrispiteLog;
import net.minecraft.client.OptionInstance;
import net.minecraft.client.Options;
import net.minecraft.client.PreferredGraphicsApi;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Options.class)
abstract class OptionsMixin {

    @Shadow
    private PreferredGraphicsApi preferredGraphicsBackendFromStartup;

    @Shadow
    @Final
    private OptionInstance<PreferredGraphicsApi> preferredGraphicsBackend;

    @Inject(method = "load", at = @At("RETURN"))
    private void krispite$forceVulkanBackend(CallbackInfo ci) {
        if (!System.getProperty("os.name", "").toLowerCase(java.util.Locale.ROOT).contains("mac")) {
            return;
        }
        this.preferredGraphicsBackend.set(PreferredGraphicsApi.VULKAN);
        this.preferredGraphicsBackendFromStartup = PreferredGraphicsApi.VULKAN;
        KrispiteLog.info("options.locked_vulkan");
    }
}
