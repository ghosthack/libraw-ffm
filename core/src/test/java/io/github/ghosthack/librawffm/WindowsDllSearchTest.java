package io.github.ghosthack.librawffm;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledOnOs;
import org.junit.jupiter.api.condition.OS;
import org.junit.jupiter.api.io.TempDir;

import java.io.File;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The bundled Windows natives are self-contained and load nothing from
 * {@code PATH}. A child JVM runs with copies of the bundled DLLs on its
 * {@code PATH} ahead of everything the host already has there (an MSYS2 or
 * Git for Windows MinGW directory, on a developer machine or CI runner);
 * every module it ends up with must come from the bundle, Windows or the
 * JDK. That catches both a {@code PATH}-searching load and a dependency the
 * bundle forgot, which on such a host would otherwise quietly load from
 * {@code PATH} and only fail on a clean machine.
 */
@EnabledOnOs(OS.WINDOWS)
class WindowsDllSearchTest {

    @Test
    void bundledNativesLoadOnlyFromTheBundle(@TempDir Path temp) throws Exception {
        Path decoy = Files.createDirectory(temp.resolve("decoy"));
        Path home = Files.createDirectory(temp.resolve("home"));
        for (String name : manifest()) {
            try (InputStream dll = resource("libraw-natives/windows-x64/" + name)) {
                Files.copy(dll, decoy.resolve(name));
            }
        }

        String classPath = System.getProperty("java.class.path");
        String modulePath = System.getProperty("jdk.module.path");
        if (modulePath != null && !modulePath.isBlank()) {
            classPath = classPath + File.pathSeparator + modulePath;
        }
        String java = ProcessHandle.current().info().command().orElseThrow();
        ProcessBuilder builder = new ProcessBuilder(java, "--enable-native-access=ALL-UNNAMED",
                "-Duser.home=" + home, "-cp", classPath, WindowsDllProbe.class.getName())
                .redirectErrorStream(true);
        // The inherited key is spelled "Path"; set that one, never a second copy.
        var environment = builder.environment();
        String pathKey = environment.keySet().stream()
                .filter(key -> key.equalsIgnoreCase("PATH")).findFirst().orElse("Path");
        environment.put(pathKey, decoy + File.pathSeparator + environment.getOrDefault(pathKey, ""));
        Process child = builder.start();
        String output = new String(child.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        assertTrue(child.waitFor(60, TimeUnit.SECONDS), "probe finished");
        assertEquals(0, child.exitValue(), output);
        assertTrue(output.contains("loaded"), output);

        Path bundle = home.resolve(".cache").resolve("libraw-ffm").toRealPath();
        Path windows = Path.of(System.getenv().getOrDefault("SystemRoot", "C:\\Windows")).toRealPath();
        Path jdk = Path.of(java).toRealPath().getParent().getParent();
        List<String> outside = new ArrayList<>();
        int bundled = 0;
        for (String line : output.lines().toList()) {
            String[] parts = line.split("\t", 2);
            if (parts.length != 2 || !parts[0].equals("module")) continue;
            Path loaded = Path.of(parts[1]).toRealPath();
            if (loaded.startsWith(bundle)) {
                bundled++;
            } else if (!loaded.startsWith(windows) && !loaded.startsWith(jdk)) {
                outside.add(loaded.toString());
            }
        }
        assertEquals(manifest().size(), bundled, "every bundled DLL loaded from the bundle\n" + output);
        assertEquals(List.of(), outside, "modules loaded from outside the bundle, Windows and the JDK");
    }

    private static List<String> manifest() throws Exception {
        try (InputStream manifest = resource("libraw-natives/windows-x64/manifest.txt")) {
            return new String(manifest.readAllBytes(), StandardCharsets.UTF_8)
                    .lines().map(String::trim).filter(l -> !l.isEmpty()).toList();
        }
    }

    private static InputStream resource(String name) {
        InputStream stream = WindowsDllSearchTest.class.getClassLoader().getResourceAsStream(name);
        if (stream == null) throw new IllegalStateException("missing test resource " + name);
        return stream;
    }
}
