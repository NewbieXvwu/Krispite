package com.krispite.mixin;

import net.minecraft.client.OptionInstance;
import net.minecraft.client.Options;
import net.minecraft.client.gui.components.AbstractWidget;
import net.minecraft.client.gui.components.Tooltip;
import net.minecraft.network.chat.Component;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(OptionInstance.class)
abstract class OptionInstanceMixin {

    @Inject(
            method = "createButton(Lnet/minecraft/client/Options;IIILnet/minecraft/client/OptionInstance$ValueUpdateListener;)Lnet/minecraft/client/gui/components/AbstractWidget;",
            at = @At("RETURN")
    )
    private void krispite$lockGraphicsBackendButton(
            Options options, int x, int y, int width,
            OptionInstance.ValueUpdateListener<?> listener,
            CallbackInfoReturnable<AbstractWidget> cir) {
        if ((Object) this == options.preferredGraphicsBackend()) {
            AbstractWidget widget = cir.getReturnValue();
            widget.active = false;
            widget.setTooltip(Tooltip.create(Component.translatable("mod.krispite.graphics_backend.locked")));
        }
    }
}
