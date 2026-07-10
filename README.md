# Krispite

[中文](README-zh.md)

[KosmicKrisp](https://docs.mesa3d.org/drivers/kosmickrisp.html) is a [Vulkan](https://www.vulkan.org) driver within the [Mesa](https://www.mesa3d.org) project that translates Vulkan calls into Apple's [Metal](https://developer.apple.com/metal/) API. This allows Mac users to ditch the antiquated OpenGL 4.1 and seamlessly enjoy the newer, Vulkan-rendered versions of Minecraft alongside other players.

Unlike [MoltenVK](https://github.com/KhronosGroup/MoltenVK), KosmicKrisp leverages Mesa's complete driver stack (including NIR compilation). It strives for full Vulkan specification compliance rather than settling for MoltenVK's "portability subset," and strictly requires macOS 26+ and Apple Silicon.

Krispite swaps out Minecraft's default MoltenVK for KosmicKrisp, delivering a more standard-compliant Vulkan experience.

# System Requirements
- Apple Silicon Mac (M1 or newer)
- macOS 26+

# Installation
Simply download the mod's JAR file and launch the game. The mod will automatically extract and load the necessary library files.

# Caveats
KosmicKrisp is currently in a phase of rapid iteration. Much of its codebase is still in a "make it work" state, lacking deep optimization. In my own MacBook tests, I found its performance to be roughly 14% lower than the default MoltenVK.

Because of this, using Krispite right now is essentially "future-proofing": providing an alternative that you might not strictly need today, but once KosmicKrisp gets properly optimized, everything is going to be awesome! 🤣

# Building from Source

**Prerequisites:** [JDK 25](https://jdk.java.net/25/) (strictly required by Minecraft 26.2), macOS 26 + Apple Silicon, and [Homebrew](https://brew.sh).

```bash
# 1. Install build dependencies (one-time)
brew install meson ninja llvm spirv-tools

# 2. Compile native libraries (required for the first build or upon upstream updates)
./tools/build_native.sh

# 3. Build the mod
./gradlew build
```

If the native libraries are missing, the build process will issue a warning but will not fail. This is designed to make it easier to compile the Java code on non-macOS systems.

# Uninstallation
Delete the mod JAR file, along with the `~/.local/share/kosmickrisp-mc/` directory and the `~/.local/share/vulkan/icd.d/libkosmickrisp_icd.json` file.