package com.krispite.mixin;

import com.mojang.blaze3d.platform.Window;
import com.mojang.blaze3d.systems.GpuBackend;
import com.mojang.blaze3d.vulkan.VulkanBackend;
import net.neoforged.fml.loading.EarlyLoadingScreenController;
import org.lwjgl.glfw.GLFW;
import org.lwjgl.opengl.GL;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(Window.class)
abstract class WindowMixin {

    @Inject(method = "createGlfwWindow", at = @At("HEAD"), cancellable = true)
    private static void krispite$createVulkanWindow(int width, int height, String title, long monitor, GpuBackend backend, CallbackInfoReturnable<Long> cir) {
        if (!(backend instanceof VulkanBackend)) {
            return;
        }

        closeNeoForgeEarlyDisplay();
        backend.setWindowHints();
        GLFW.glfwWindowHint(GLFW.GLFW_VISIBLE, GLFW.GLFW_FALSE);
        long windowHandle = GLFW.glfwCreateWindow(width, height, title, monitor, 0L);
        if (windowHandle == 0L) {
            cir.setReturnValue(0L);
        } else {
            cir.setReturnValue(windowHandle);
        }
    }

    private static void closeNeoForgeEarlyDisplay() {
        EarlyLoadingScreenController earlyDisplay = EarlyLoadingScreenController.current();
        if (earlyDisplay == null) {
            return;
        }

        long earlyWindow = earlyDisplay.takeOverGlfwWindow();
        if (earlyWindow == 0L) {
            return;
        }

        GL.createCapabilities();
        try {
            earlyDisplay.getClass().getMethod("close").invoke(earlyDisplay);
        } catch (ReflectiveOperationException exception) {
            throw new IllegalStateException("Unable to close NeoForge early display for Vulkan", exception);
        } finally {
            GLFW.glfwMakeContextCurrent(0L);
            GLFW.glfwDestroyWindow(earlyWindow);
        }
    }
}
