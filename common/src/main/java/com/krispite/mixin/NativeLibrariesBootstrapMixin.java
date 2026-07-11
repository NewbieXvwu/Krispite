package com.krispite.mixin;

import com.krispite.KrispiteEarlySetup;
import com.mojang.blaze3d.platform.NativeLibrariesBootstrap;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(NativeLibrariesBootstrap.class)
abstract class NativeLibrariesBootstrapMixin {

    @Inject(method = "tryLoadingVulkan", at = @At("HEAD"))
    private static void krispite$setupVulkanLoader(CallbackInfoReturnable<Boolean> cir) {
        KrispiteEarlySetup.init();
    }
}
