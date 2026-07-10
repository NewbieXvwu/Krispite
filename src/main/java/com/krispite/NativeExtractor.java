package com.krispite;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Properties;

/** Extracts the Vulkan loader and KosmicKrisp ICD bundled in the mod jar. */
public final class NativeExtractor {
    private static final String RESOURCE_PREFIX = "/natives/";
    private static final String KOSMICKRISP_LIBRARY = "libvulkan_kosmickrisp.dylib";
    private static final String VULKAN_LOADER = "libvulkan.1.dylib";
    private static final String ICD_FILE = "libkosmickrisp_icd.json";
    private static final String VERSION_FILE = "natives-version.properties";
    private static final String VERSION_KEY = "krispite.native.version";

    private NativeExtractor() {
    }

    public static Path dataDirectory() {
        String override = System.getProperty("krispite.dataDir");
        if (override != null && !override.isBlank()) {
            return Path.of(override);
        }
        return Path.of(System.getProperty("user.home"), ".local", "share", "kosmickrisp-mc");
    }

    public static Path libraryDirectory() {
        return dataDirectory().resolve("lib");
    }

    public static Path icdDirectory() {
        String override = System.getProperty("krispite.icdDir");
        if (override != null && !override.isBlank()) {
            return Path.of(override);
        }
        return Path.of(System.getProperty("user.home"), ".local", "share", "vulkan", "icd.d");
    }

    public static Path vulkanLoaderPath() {
        return libraryDirectory().resolve(VULKAN_LOADER);
    }

    public static Path kosmicKrispPath() {
        return libraryDirectory().resolve(KOSMICKRISP_LIBRARY);
    }

    public static Path icdPath() {
        return icdDirectory().resolve(ICD_FILE);
    }

    public static synchronized void extract() throws IOException {
        if (!isResourcePresent(KOSMICKRISP_LIBRARY)) {
            throw new IOException(KrispiteLog.get("native.missing_resource", KOSMICKRISP_LIBRARY));
        }
        Files.createDirectories(libraryDirectory());
        String bundledVersion = readBundledVersion();
        String installedVersion = readInstalledVersion();
        if (bundledVersion != null && bundledVersion.equals(installedVersion)
                && Files.exists(kosmicKrispPath()) && Files.exists(vulkanLoaderPath())) {
            return;
        }
        extractResource(KOSMICKRISP_LIBRARY, kosmicKrispPath());
        extractResource(VULKAN_LOADER, vulkanLoaderPath());
        if (bundledVersion != null) {
            writeInstalledVersion(bundledVersion);
        }
    }

    public static synchronized void writeIcdJson() throws IOException {
        Files.createDirectories(icdDirectory());
        String template = readTextResource(ICD_FILE);
        String json = template.replace("${library_path}", jsonString(kosmicKrispPath().toAbsolutePath().toString()));
        writeIfChanged(icdPath(), json.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    static boolean isResourcePresent(String name) {
        return NativeExtractor.class.getResource(RESOURCE_PREFIX + name) != null;
    }

    static String readBundledVersion() {
        try (InputStream input = NativeExtractor.class.getResourceAsStream(RESOURCE_PREFIX + VERSION_FILE)) {
            if (input == null) {
                return null;
            }
            Properties props = new Properties();
            props.load(input);
            return props.getProperty(VERSION_KEY);
        } catch (IOException exception) {
            return null;
        }
    }

    static String readBundledVersionDetail() {
        try (InputStream input = NativeExtractor.class.getResourceAsStream(RESOURCE_PREFIX + VERSION_FILE)) {
            if (input == null) {
                return KrispiteLog.get("native.no_version");
            }
            Properties props = new Properties();
            props.load(input);
            StringBuilder sb = new StringBuilder();
            for (String key : new String[]{
                    "krispite.native.mesa_commit",
                    "krispite.native.loader_commit",
                    "krispite.native.build_date"}) {
                String value = props.getProperty(key);
                if (value != null) {
                    if (!sb.isEmpty()) {
                        sb.append(", ");
                    }
                    sb.append(key.substring(key.lastIndexOf('.') + 1)).append("=").append(value);
                }
            }
            return sb.toString();
        } catch (IOException exception) {
            return KrispiteLog.get("native.no_version");
        }
    }

    private static String readInstalledVersion() throws IOException {
        Path versionPath = libraryDirectory().resolve(VERSION_FILE);
        if (!Files.exists(versionPath)) {
            return null;
        }
        try (InputStream input = Files.newInputStream(versionPath)) {
            Properties props = new Properties();
            props.load(input);
            return props.getProperty(VERSION_KEY);
        }
    }

    private static void writeInstalledVersion(String version) throws IOException {
        Properties props = new Properties();
        props.setProperty(VERSION_KEY, version);
        String bundledDetail = readBundledVersionDetail();
        if (!bundledDetail.isEmpty()) {
            props.setProperty("krispite.native.detail", bundledDetail);
        }
        try (java.io.OutputStream out = Files.newOutputStream(libraryDirectory().resolve(VERSION_FILE))) {
            props.store(out, "Krispite native library version");
        }
    }

    private static void extractResource(String resourceName, Path target) throws IOException {
        Path temporary = Files.createTempFile(target.getParent(), target.getFileName().toString(), ".tmp");
        try (InputStream input = openResource(resourceName)) {
            Files.copy(input, temporary, StandardCopyOption.REPLACE_EXISTING);
            moveAtomically(temporary, target);
        } finally {
            Files.deleteIfExists(temporary);
        }
    }

    private static String readTextResource(String resourceName) throws IOException {
        try (InputStream input = openResource(resourceName)) {
            return new String(input.readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
        }
    }

    private static InputStream openResource(String resourceName) throws IOException {
        InputStream input = NativeExtractor.class.getResourceAsStream(RESOURCE_PREFIX + resourceName);
        if (input == null) {
            throw new IOException(KrispiteLog.get("native.missing_resource", resourceName));
        }
        return input;
    }

    private static void writeIfChanged(Path target, byte[] content) throws IOException {
        if (Files.exists(target) && java.util.Arrays.equals(Files.readAllBytes(target), content)) {
            return;
        }
        Path temporary = Files.createTempFile(target.getParent(), target.getFileName().toString(), ".tmp");
        try {
            Files.write(temporary, content);
            moveAtomically(temporary, target);
        } finally {
            Files.deleteIfExists(temporary);
        }
    }

    private static void moveAtomically(Path source, Path target) throws IOException {
        try {
            Files.move(source, target, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } catch (AtomicMoveNotSupportedException exception) {
            Files.move(source, target, StandardCopyOption.REPLACE_EXISTING);
        }
    }

    private static String jsonString(String text) {
        return text.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
