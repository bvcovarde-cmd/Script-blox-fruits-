package com.ghost.gameturbo;

import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

final class TurboPrefs {
    private final SharedPreferences p;
    TurboPrefs(Context c) { p = c.getSharedPreferences("game_turbo_pro", Context.MODE_PRIVATE); }

    Set<String> manualGames() { return new HashSet<>(p.getStringSet("manual_games", Collections.emptySet())); }
    void saveManualGames(Set<String> set) { p.edit().putStringSet("manual_games", new HashSet<>(set)).apply(); }

    boolean profileDnd(String pkg) { return p.getBoolean("profile_" + pkg + "_dnd", true); }
    int profileVolume(String pkg) { return p.getInt("profile_" + pkg + "_volume", 80); }
    int profileBrightness(String pkg) { return p.getInt("profile_" + pkg + "_brightness", 65); }
    void saveProfile(String pkg, boolean dnd, int volume, int brightness) {
        p.edit().putBoolean("profile_" + pkg + "_dnd", dnd)
                .putInt("profile_" + pkg + "_volume", volume)
                .putInt("profile_" + pkg + "_brightness", brightness).apply();
    }

    boolean has(String key) { return p.contains(key); }
    int getInt(String key, int def) { return p.getInt(key, def); }
    void putInt(String key, int value) { p.edit().putInt(key, value).apply(); }
    long played(String pkg) { return p.getLong("played_" + pkg, 0L); }

    void startSession(String pkg, String label) {
        p.edit().putString("active_pkg", pkg).putString("active_label", label)
                .putLong("active_start", System.currentTimeMillis()).apply();
    }

    boolean hasActiveSession() { return !TextUtils.isEmpty(p.getString("active_pkg", "")); }

    String finishSession() {
        String pkg = p.getString("active_pkg", "");
        String label = p.getString("active_label", pkg);
        long start = p.getLong("active_start", 0L);
        if (TextUtils.isEmpty(pkg) || start <= 0L) return null;
        long elapsed = Math.max(0L, System.currentTimeMillis() - start);
        if (elapsed < 5000L) return null;
        long total = p.getLong("played_" + pkg, 0L) + elapsed;
        String line = label + " • " + DeviceMonitor.duration(elapsed);
        String old = p.getString("history", "");
        String next = line + (TextUtils.isEmpty(old) ? "" : "\n" + old);
        String[] lines = next.split("\n");
        StringBuilder limited = new StringBuilder();
        for (int i = 0; i < Math.min(12, lines.length); i++) {
            if (i > 0) limited.append('\n');
            limited.append(lines[i]);
        }
        p.edit().putLong("played_" + pkg, total).putString("history", limited.toString())
                .remove("active_pkg").remove("active_label").remove("active_start").apply();
        return line;
    }

    String history() {
        String h = p.getString("history", "");
        return TextUtils.isEmpty(h) ? "Nenhuma sessão registrada." : h;
    }

    void clearRestoreKeys() {
        p.edit().remove("restore_volume").remove("restore_brightness")
                .remove("restore_brightness_mode").remove("restore_dnd").apply();
    }
}
