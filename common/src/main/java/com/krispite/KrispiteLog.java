package com.krispite;

import java.text.MessageFormat;
import java.util.Locale;
import java.util.MissingResourceException;
import java.util.ResourceBundle;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class KrispiteLog {
    private static final Logger LOGGER = LoggerFactory.getLogger("Krispite");
    private static final ResourceBundle BUNDLE = loadBundle();

    private KrispiteLog() {
    }

    private static ResourceBundle loadBundle() {
        try {
            return ResourceBundle.getBundle("com.krispite.messages", Locale.getDefault());
        } catch (MissingResourceException exception) {
            return new EmptyBundle();
        }
    }

    public static Logger logger() {
        return LOGGER;
    }

    public static String get(String key, Object... args) {
        String pattern;
        try {
            pattern = BUNDLE.getString(key);
        } catch (MissingResourceException exception) {
            return key;
        }
        return MessageFormat.format(pattern, args);
    }

    public static void info(String key, Object... args) {
        LOGGER.info("{}", get(key, args));
    }

    public static void warn(String key, Object... args) {
        LOGGER.warn("{}", get(key, args));
    }

    public static void error(String key, Throwable throwable, Object... args) {
        LOGGER.error("{}", get(key, args), throwable);
    }

    private static final class EmptyBundle extends ResourceBundle {
        @Override
        protected Object handleGetObject(String key) {
            return null;
        }

        @Override
        public java.util.Enumeration<String> getKeys() {
            return java.util.Collections.emptyEnumeration();
        }
    }
}
