package com.krispite.neoforge;

import com.krispite.KrispiteEarlySetup;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.fml.common.Mod;

/** NeoForge mod entrypoint — delegates to the shared early setup. */
@Mod(value = "krispite", dist = Dist.CLIENT)
public final class KrispiteNeoForge {

    public KrispiteNeoForge() {
        KrispiteEarlySetup.init();
    }
}
