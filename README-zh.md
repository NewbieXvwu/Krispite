# Krispite

[English](README.md)

[KosmicKrisp](https://docs.mesa3d.org/drivers/kosmickrisp.html) 是 [Mesa](https://www.mesa3d.org) 中的一个 [Vulkan](https://www.vulkan.org) 驱动，把 Vulkan 调用翻译成 Apple 的 [Metal API](https://developer.apple.com/metal/)。这使得 Mac 用户可以和其他玩家一起畅玩使用 Vulkan API 渲染的新版 Minecraft，抛弃老旧的 OpenGL 4.1。
和 [MoltenVK](https://github.com/KhronosGroup/MoltenVK) 不同，KosmicKrisp 走的是 Mesa 的完整驱动栈（NIR 编译等），追求完整的 Vulkan 规范合规而非 MoltenVK 的"可移植性子集"，且强制要求 macOS 26+ 和 Apple Silicon。
Krispite 用它替换 Minecraft 默认的 MoltenVK，获得更标准的 Vulkan 支持。

# 设备要求
- Apple Silicon Mac（M1 及以上）
- macOS 26+
- Minecraft 26.2+
- [Fabric Loader](https://fabricmc.net/) **或** [NeoForge](https://neoforged.net/)

# 安装
1. 从 [Releases](https://github.com/NewbieXvwu/Krispite/releases) 下载与你加载器对应的 JAR：
   - Fabric：`krispite-fabric-*.jar`
   - NeoForge：`krispite-neoforge-*.jar`
2. 放入 Minecraft 的 `mods` 文件夹并启动游戏。

模组会自动将必要的库文件解压并加载。

# 代价
目前 KosmicKrisp 仍处于高速迭代期，大量代码处于能跑就行的状态，缺少深度优化。在我的 MacBook 上测试发现它的性能比默认的 MoltenVK 低大约 14%。
因此 Krispite 目前也就是处于一种"战未来"的状态：先给你一个暂时用不上的备选方案，等 KosmicKrisp 做好优化，一切都会好起来的！🤣

# 开发者构建

前置条件：[JDK 25](https://jdk.java.net/25/)（Minecraft 26.2 强制要求）、macOS 26 + Apple Silicon（编译原生库时需要）、[Homebrew](https://brew.sh)。

```bash
# 1. 安装编译依赖（一次性）
brew install meson ninja llvm spirv-tools

# 2. 编译原生库（首次构建或上游更新时需要）
./tools/build_native.sh

# 3. 编译模组（同时产出 Fabric 与 NeoForge JAR）
./gradlew build
```

产物：
- `fabric/build/libs/krispite-fabric-<version>.jar`
- `neoforge/build/libs/krispite-neoforge-<version>.jar`

原生库缺失时构建会警告但不会失败，方便在非 macOS 上编译 Java 代码。

# 卸载
删掉 mod JAR、`~/.local/share/kosmickrisp-mc/` 和 `~/.local/share/vulkan/icd.d/libkosmickrisp_icd.json`。
