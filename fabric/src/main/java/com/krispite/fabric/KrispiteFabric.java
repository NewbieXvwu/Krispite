package com.krispite.fabric;

import com.krispite.KrispiteEarlySetup;
import net.fabricmc.loader.api.entrypoint.PreLaunchEntrypoint;

/** Fabric preLaunch entrypoint — delegates to the shared early setup. */
public final class KrispiteFabric implements PreLaunchEntrypoint {

    @Override
    public void onPreLaunch() {
        KrispiteEarlySetup.init();
    }
}
