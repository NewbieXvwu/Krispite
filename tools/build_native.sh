#!/bin/bash
set -euo pipefail

# --- i18n ---
case "${KRISPITE_LANG:-${LANG:-zh}}" in
  en*|EN*) KRISPITE_LANG=en ;;
  *)       KRISPITE_LANG=zh ;;
esac
if [ "$KRISPITE_LANG" = "en" ]; then
  msg_usage_title="Build native libraries (Vulkan Loader + KosmicKrisp) for macOS arm64"
  msg_usage_body="Usage:  ./tools/build_native.sh                            # First build or incremental build (no git pull)
  KRISPITE_NATIVE_REFRESH=1 ./tools/build_native.sh  # Force git pull before building"
  msg_env_workdir="Native library build work directory (default .native-build)"
  msg_env_refresh="Set to 1 to force git pull upstream"
  msg_checking_tools="Checking build tools..."
  msg_cloning="Cloning upstream repos..."
  msg_building_mesa="Building Mesa (KosmicKrisp)..."
  msg_building_loader="Building Vulkan-Loader..."
  msg_code_sign="Code-signing dylibs..."
  msg_license_verify="Verifying KosmicKrisp source license..."
  msg_license_changed="KosmicKrisp source license has changed, current identifiers:"
  msg_license_review="Please review the license and update the license generation logic."
  msg_license_exit="Aborting build."
  msg_generating_version="Generating version info..."
  msg_generating_legal="Generating license files for distribution..."
  msg_done="Build complete:"
  msg_mesa="Mesa"
  msg_loader="Vulkan-Loader"
  msg_build_date="Build date"
  msg_version_id="Version tag"
  msg_version_written="Version info written to"
  msg_legal_written="License files written to"
  msg_missing_resource="Krispite jar is missing native file"
  msg_no_version="Native library version info not available"
  msg_tool_missing="Required tool not found, please install it first:"
  msg_native_ok="Native libraries ready."
  msg_native_missing="Native libraries missing"
  msg_build_native_hint="Please run ./tools/build_native.sh to build native libraries."
  msg_ci_skip="Skipping native library check (CI build or cross-platform)."
  msg_xcode_missing="Xcode Command Line Tools not found."
  msg_xcode_install="Install: xcode-select --install"
  msg_sdk_empty="xcrun --show-sdk-path returned empty — Xcode CLI tools may be misconfigured."
  msg_brew_prereq="Install Homebrew dependencies: brew install"
else
  msg_usage_title="从 Mesa 与 Vulkan-Loader 源码构建 Krispite 随附的 macOS arm64 原生库"
  msg_usage_body="用法:
  ./tools/build_native.sh                            # 首次构建或增量编译（不重新拉取上游）
  KRISPITE_NATIVE_REFRESH=1 ./tools/build_native.sh  # 强制拉取上游最新代码后重新编译"
  msg_env_workdir="原生库构建工作目录（默认 .native-build）"
  msg_env_refresh="设为 1 则强制 git pull 上游最新代码"
  msg_checking_tools="检查构建工具..."
  msg_cloning="克隆上游仓库..."
  msg_building_mesa="编译 Mesa（KosmicKrisp）..."
  msg_building_loader="编译 Vulkan-Loader..."
  msg_code_sign="签名 dylib..."
  msg_license_verify="验证 KosmicKrisp 源码许可证..."
  msg_license_changed="KosmicKrisp 源码许可证发生变化，当前标识为:"
  msg_license_review="请先审核许可证内容，再更新许可证生成逻辑。"
  msg_license_exit="构建中止。"
  msg_generating_version="生成版本信息..."
  msg_generating_legal="生成分发许可证文件..."
  msg_done="原生库构建完成:"
  msg_mesa="Mesa"
  msg_loader="Vulkan-Loader"
  msg_build_date="构建时间"
  msg_version_id="版本标识"
  msg_version_written="版本信息已写入"
  msg_legal_written="许可证已写入"
  msg_missing_resource="Krispite 安装包缺少原生文件"
  msg_no_version="原生库版本信息不可用"
  msg_tool_missing="未找到所需工具，请先安装:"
  msg_native_ok="原生库就绪。"
  msg_native_missing="原生库缺失"
  msg_build_native_hint="请运行 ./tools/build_native.sh 编译原生库。"
  msg_ci_skip="跳过原生库检查（跨平台 CI 构建）。"
  msg_xcode_missing="未找到 Xcode Command Line Tools。"
  msg_xcode_install="安装命令: xcode-select --install"
  msg_sdk_empty="xcrun --show-sdk-path 返回空 — Xcode CLI 工具可能配置异常。"
  msg_brew_prereq="请先安装 Homebrew 依赖: brew install"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${KRISPITE_NATIVE_WORKDIR:-$ROOT/.native-build}"

echo "$msg_checking_tools"

# --- OS prerequisites ---
if ! command -v xcrun >/dev/null; then
  echo "  $msg_xcode_missing" >&2
  echo "  $msg_xcode_install" >&2
  exit 1
fi
export SDKROOT="$(xcrun --show-sdk-path)"
if [ -z "$SDKROOT" ]; then
  echo "  $msg_sdk_empty" >&2
  echo "  $msg_xcode_install" >&2
  exit 1
fi
echo "  macOS SDK: $SDKROOT"

# --- Homebrew dependencies ---
MISSING=""
for brew_pkg in meson ninja llvm spirv-tools; do
  brew list "$brew_pkg" &>/dev/null || MISSING="$MISSING $brew_pkg"
done
if [ -n "$MISSING" ]; then
  echo "  $msg_brew_prereq$MISSING" >&2
  exit 1
fi
echo "  meson $(meson --version 2>/dev/null || echo '?')"
echo "  ninja $(ninja --version 2>/dev/null || echo '?')"

# --- cmake (prefer 3.x) ---
PATH="$HOME/.local/bin:/opt/homebrew/opt/llvm/bin:/opt/homebrew/opt/cmake/bin:$PATH"
export PKG_CONFIG_PATH="/opt/homebrew/opt/llvm/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
CMAKE="$(command -v cmake 2>/dev/null || true)"
if [ -z "$CMAKE" ] || cmake --version 2>/dev/null | grep -q 'cmake version 4\.'; then
  for candidate in /opt/homebrew/bin/cmake "$HOME/.local/share/mise/installs/python/3.14/bin/cmake" /usr/local/bin/cmake; do
    if [ -x "$candidate" ] && "$candidate" --version 2>/dev/null | grep -q 'cmake version 3\.'; then
      CMAKE="$candidate"
      break
    fi
  done
fi
if [ -z "$CMAKE" ]; then
  echo "  $msg_tool_missing cmake" >&2
  echo "  brew install cmake" >&2
  exit 1
fi
echo "  cmake $($CMAKE --version 2>/dev/null | head -1)"

MESA_DIR="$WORK/mesa"
LOADER_DIR="$WORK/Vulkan-Loader"
MESA_BUILD="$MESA_DIR/build-krispite"
LOADER_BUILD="$LOADER_DIR/build-krispite"
OUTPUT="$ROOT/src/main/resources/natives"
VERSION_FILE="$OUTPUT/natives-version.properties"
LEGAL_OUTPUT="$ROOT/src/main/resources/META-INF/licenses/kosmickrisp"

mkdir -p "$WORK" "$OUTPUT"
mkdir -p "$LEGAL_OUTPUT"

clone_or_pull() {
  local url="$1" dir="$2"
  if [ ! -d "$dir/.git" ]; then
    git clone --depth 1 "$url" "$dir"
  elif [ "${KRISPITE_NATIVE_REFRESH:-0}" = "1" ]; then
    git -C "$dir" pull --ff-only
  fi
}

echo "$msg_cloning"
clone_or_pull https://gitlab.freedesktop.org/mesa/mesa.git "$MESA_DIR"
clone_or_pull https://github.com/KhronosGroup/Vulkan-Loader.git "$LOADER_DIR"

echo "$msg_building_mesa"
meson setup "$MESA_BUILD" "$MESA_DIR" --wipe \
  -Dplatforms=macos \
  -Dvulkan-drivers=kosmickrisp \
  -Dgallium-drivers= \
  -Dopengl=false \
  -Dzstd=disabled \
  -Ddefault_library=static \
  --prefer-static \
  -Dbuildtype=release \
  -Dc_args="-isysroot $SDKROOT" \
  -Dcpp_args="-isysroot $SDKROOT" \
  -Dobjc_args="-isysroot $SDKROOT"
ninja -C "$MESA_BUILD"

echo "$msg_building_loader"
VK_HEADERS_DIR=""
for hdir in "$WORK/Vulkan-Headers/install/share/cmake/VulkanHeaders" \
            "/opt/homebrew/opt/vulkan-headers/share/cmake/VulkanHeaders"; do
  if [ -f "$hdir/VulkanHeadersConfig.cmake" ]; then
    VK_HEADERS_DIR="$hdir"
    break
  fi
done
if [ -z "$VK_HEADERS_DIR" ]; then
  echo "  Building Vulkan-Headers from source..." >&2
  VK_HEADERS_SRC="$WORK/Vulkan-Headers"
  rm -rf "$VK_HEADERS_SRC"
  git clone --depth 1 --branch vulkan-tmp-1.4.356 \
    https://github.com/KhronosGroup/Vulkan-Headers.git "$VK_HEADERS_SRC"
  mkdir -p "$VK_HEADERS_SRC/build"
  "$CMAKE" -S "$VK_HEADERS_SRC" -B "$VK_HEADERS_SRC/build" \
    -DCMAKE_INSTALL_PREFIX="$VK_HEADERS_SRC/install" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  "$CMAKE" --build "$VK_HEADERS_SRC/build"
  "$CMAKE" --install "$VK_HEADERS_SRC/build"
  VK_HEADERS_DIR="$VK_HEADERS_SRC/install/share/cmake/VulkanHeaders"
fi
"$CMAKE" -S "$LOADER_DIR" -B "$LOADER_BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTS=OFF \
  -DBUILD_WSI_WAYLAND_SUPPORT=OFF \
  -DBUILD_WSI_XCB_SUPPORT=OFF \
  -DBUILD_WSI_XLIB_SUPPORT=OFF \
  -DVulkanHeaders_DIR="$VK_HEADERS_DIR"
"$CMAKE" --build "$LOADER_BUILD" --config Release

install -m 755 "$MESA_BUILD/src/kosmickrisp/vulkan/libvulkan_kosmickrisp.dylib" "$OUTPUT/libvulkan_kosmickrisp.dylib"
install -m 755 "$LOADER_BUILD/loader/libvulkan.1.dylib" "$OUTPUT/libvulkan.1.dylib"
echo "$msg_code_sign"
codesign --force --sign - "$OUTPUT/libvulkan_kosmickrisp.dylib" "$OUTPUT/libvulkan.1.dylib"

MESA_COMMIT="$(git -C "$MESA_DIR" rev-parse --short HEAD)"
LOADER_COMMIT="$(git -C "$LOADER_DIR" rev-parse --short HEAD)"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
MESA_SHA256="$(shasum -a 256 "$OUTPUT/libvulkan_kosmickrisp.dylib" | cut -d' ' -f1)"
LOADER_SHA256="$(shasum -a 256 "$OUTPUT/libvulkan.1.dylib" | cut -d' ' -f1)"
NATIVE_VERSION="${MESA_COMMIT}+${LOADER_COMMIT}"

KOSMICKRISP_LICENSE_IDS="$(
  git -C "$MESA_DIR" grep -h -o -E 'SPDX-License-Identifier:[[:space:]]*[^[:space:]]+' -- src/kosmickrisp \
    | sed -E 's/.*SPDX-License-Identifier:[[:space:]]*//' \
    | LC_ALL=C sort -u
)"
echo "$msg_license_verify"
if [ "$KOSMICKRISP_LICENSE_IDS" != "MIT" ]; then
  echo "$msg_license_changed ${KOSMICKRISP_LICENSE_IDS:-<not found>}" >&2
  echo "$msg_license_review" >&2
  echo "$msg_license_exit" >&2
  exit 1
fi

echo "$msg_generating_version"
cat > "$VERSION_FILE" <<PROPS
krispite.native.version=${NATIVE_VERSION}
krispite.native.mesa_commit=${MESA_COMMIT}
krispite.native.loader_commit=${LOADER_COMMIT}
krispite.native.build_date=${BUILD_DATE}
krispite.native.mesa_sha256=${MESA_SHA256}
krispite.native.loader_sha256=${LOADER_SHA256}
PROPS

echo "$msg_generating_legal"
# Mesa/KosmicKrisp does not ship LICENSE.txt or THIRD_PARTY_NOTICES.txt by name.
# We generate them from the exact source revisions used in this build.
{
  printf '%s\n\n' 'KosmicKrisp source component from Mesa'
  printf '%s\n' 'Copyright notices:'
  git -C "$MESA_DIR" grep -h -i 'Copyright' -- src/kosmickrisp \
    | sed 's/^[[:space:]/*#-]*//' \
    | LC_ALL=C sort -u
  printf '\n%s\n' 'License: MIT'
  awk '
    /^License-Text:/ { in_license = 1; next }
    in_license && /^Copyright \(c\) <year> <copyright holders>$/ { next }
    in_license { print }
  ' "$MESA_DIR/licenses/MIT"
} > "$LEGAL_OUTPUT/LICENSE"

{
  printf '%s\n' 'THIRD-PARTY NOTICES'
  printf '%s\n' 'This file is generated from the exact native-library source revisions used for this build.'
  printf '%s\n' "Mesa commit: ${MESA_COMMIT}"
  printf '%s\n\n' "Vulkan-Loader commit: ${LOADER_COMMIT}"

  printf '%s\n' 'KosmicKrisp / Mesa'
  printf '%s\n' "KosmicKrisp source SPDX identifiers: ${KOSMICKRISP_LICENSE_IDS}"
  printf '%s\n\n' 'Mesa license policy and component information:'
  cat "$MESA_DIR/docs/license.rst"

  for license_file in "$MESA_DIR"/licenses/*; do
    [ -f "$license_file" ] || continue
    printf '\n===== Mesa license: %s =====\n' "$(basename "$license_file")"
    cat "$license_file"
  done

  for notice_file in "$LOADER_DIR"/LICENSE* "$LOADER_DIR"/NOTICE* "$LOADER_DIR"/COPYING*; do
    [ -f "$notice_file" ] || continue
    printf '\n===== Vulkan-Loader notice: %s =====\n' "$(basename "$notice_file")"
    cat "$notice_file"
  done

  for license_file in "$LOADER_DIR"/LICENSES/*; do
    [ -f "$license_file" ] || continue
    printf '\n===== Vulkan-Loader license: LICENSES/%s =====\n' "$(basename "$license_file")"
    cat "$license_file"
  done
} > "$LEGAL_OUTPUT/THIRD_PARTY_NOTICES.txt"

echo "$msg_done"
echo "  ${msg_mesa}:          ${MESA_COMMIT}"
echo "  ${msg_loader}: ${LOADER_COMMIT}"
echo "  ${msg_build_date}:      ${BUILD_DATE}"
echo "  ${msg_version_id}:      ${NATIVE_VERSION}"
echo "  ${msg_version_written}: ${VERSION_FILE}"
echo "  ${msg_legal_written}:  ${LEGAL_OUTPUT}"
