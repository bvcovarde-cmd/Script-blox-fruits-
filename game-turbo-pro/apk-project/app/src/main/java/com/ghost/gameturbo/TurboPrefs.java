package com.ghost.gameturbo;

import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

final class TurboPrefs {
    private final SharedPreferences p;
    TurboPrefs(Context c) { p = c.getSharedPreferences("game_turbo_pro", Context.MODE_PRIVATE); }

    Set<String> manualGames() { return set("manual_games"); }
    void saveManualGames(Set<String> set) { saveSet("manual_games", set); }
    Set<String> favorites() { return set("favorites"); }
    void saveFavorites(Set<String> set) { saveSet("favorites", set); }
    Set<String> pinned() { return set("pinned"); }
    void savePinned(Set<String> set) { saveSet("pinned", set); }
    private Set<String> set(String k) { return new HashSet<>(p.getStringSet(k, Collections.emptySet())); }
    private void saveSet(String k, Set<String> v) { p.edit().putStringSet(k, new HashSet<>(v)).apply(); }

    String profileMode(String pkg) { return p.getString("profile_" + pkg + "_mode", "Equilibrado"); }
    boolean profileDnd(String pkg) { return p.getBoolean("profile_" + pkg + "_dnd", true); }
    boolean profileOverlay(String pkg) { return p.getBoolean("profile_" + pkg + "_overlay", false); }
    int profileVolume(String pkg) { return p.getInt("profile_" + pkg + "_volume", 80); }
    int profileBrightness(String pkg) { return p.getInt("profile_" + pkg + "_brightness", 65); }
    void saveProfile(String pkg, String mode, boolean dnd, boolean overlay, int volume, int brightness) {
        p.edit().putString("profile_" + pkg + "_mode", mode)
                .putBoolean("profile_" + pkg + "_dnd", dnd)
                .putBoolean("profile_" + pkg + "_overlay", overlay)
                .putInt("profile_" + pkg + "_volume", volume)
                .putInt("profile_" + pkg + "_brightness", brightness).apply();
    }
    void applyPreset(String pkg, String mode) {
        if ("Desempenho".equals(mode)) saveProfile(pkg, mode, true, true, 90, 80);
        else if ("Economia".equals(mode)) saveProfile(pkg, mode, false, false, 65, 45);
        else saveProfile(pkg, "Equilibrado", true, false, 80, 65);
    }

    boolean has(String key) { return p.contains(key); }
    int getInt(String key, int def) { return p.getInt(key, def); }
    long getLong(String key, long def) { return p.getLong(key, def); }
    String getString(String key, String def) { return p.getString(key, def); }
    void putInt(String key, int value) { p.edit().putInt(key, value).apply(); }
    void putLong(String key, long value) { p.edit().putLong(key, value).apply(); }
    void putString(String key, String value) { p.edit().putString(key, value).apply(); }

    long played(String pkg) {
        long total = 0L;
        for (SessionRecord r : sessions()) if (pkg.equals(r.packageName)) total += r.duration();
        return total;
    }

    void startSession(String pkg, String label, String profile, DeviceMonitor.Sample sample) {
        p.edit().putString("active_pkg", pkg).putString("active_label", label)
                .putString("active_profile", profile)
                .putLong("active_start", System.currentTimeMillis())
                .putInt("active_battery", sample.batteryPercent)
                .putFloat("active_temp", sample.batteryTemp)
                .putFloat("active_temp_max", sample.batteryTemp)
                .putString("active_network", sample.network)
                .apply();
    }

    boolean hasActiveSession() { return !TextUtils.isEmpty(p.getString("active_pkg", "")); }
    String activePackage() { return p.getString("active_pkg", ""); }
    long activeStart() { return p.getLong("active_start", 0L); }

    void updateActiveTemperature(float value) {
        if (Float.isNaN(value) || !hasActiveSession()) return;
        float old = p.getFloat("active_temp_max", value);
        if (Float.isNaN(old) || value > old) p.edit().putFloat("active_temp_max", value).apply();
    }

    SessionRecord finishSession(DeviceMonitor.Sample end) {
        String pkg = p.getString("active_pkg", "");
        String label = p.getString("active_label", pkg);
        long start = p.getLong("active_start", 0L);
        if (TextUtils.isEmpty(pkg) || start <= 0L) return null;
        long finish = System.currentTimeMillis();
        if (finish - start < 3000L) { clearActive(); return null; }
        SessionRecord r = new SessionRecord();
        r.packageName = pkg; r.label = label; r.startedAt = start; r.endedAt = finish;
        r.profile = p.getString("active_profile", "Personalizado");
        r.batteryStart = p.getInt("active_battery", -1); r.batteryEnd = end.batteryPercent;
        r.tempStart = p.getFloat("active_temp", Float.NaN);
        r.tempMax = p.getFloat("active_temp_max", r.tempStart);
        r.networkStart = p.getString("active_network", ""); r.networkEnd = end.network;
        List<SessionRecord> all = sessions();
        all.add(0, r);
        saveSessions(all);
        clearActive();
        return r;
    }

    void clearActive() {
        p.edit().remove("active_pkg").remove("active_label").remove("active_profile")
                .remove("active_start").remove("active_battery").remove("active_temp")
                .remove("active_temp_max").remove("active_network").apply();
    }

    List<SessionRecord> sessions() {
        List<SessionRecord> out = new ArrayList<>();
        try {
            JSONArray a = new JSONArray(p.getString("sessions_json", "[]"));
            for (int i = 0; i < a.length(); i++) out.add(SessionRecord.from(a.getJSONObject(i)));
        } catch (Exception ignored) {}
        return out;
    }

    void saveSessions(List<SessionRecord> list) {
        JSONArray a = new JSONArray();
        for (int i = 0; i < Math.min(200, list.size()); i++) {
            try { a.put(list.get(i).json()); } catch (Exception ignored) {}
        }
        p.edit().putString("sessions_json", a.toString()).apply();
    }

    void deleteSession(int index) {
        List<SessionRecord> s = sessions();
        if (index >= 0 && index < s.size()) { s.remove(index); saveSessions(s); }
    }
    void clearHistory() { p.edit().remove("sessions_json").apply(); }

    String historyText() {
        List<SessionRecord> s = sessions();
        if (s.isEmpty()) return "Nenhuma sessão registrada.";
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < Math.min(12, s.size()); i++) {
            SessionRecord r=s.get(i);
            if (i>0) b.append('\n');
            b.append(r.label).append(" • ").append(DeviceMonitor.duration(r.duration()));
            if (r.batteryStart >= 0 && r.batteryEnd >= 0) b.append(" • bateria ").append(Math.max(0,r.batteryStart-r.batteryEnd)).append("%");
        }
        return b.toString();
    }

    String exportSessionsJson() {
        JSONArray a = new JSONArray();
        for (SessionRecord r : sessions()) try { a.put(r.json()); } catch (Exception ignored) {}
        try { return a.toString(2); } catch (Exception e) { return a.toString(); }
    }

    String exportSessionsCsv() {
        StringBuilder b=new StringBuilder("jogo,pacote,inicio,fim,duracao_ms,bateria_inicio,bateria_fim,temp_max,rede_inicio,rede_fim,perfil\n");
        for(SessionRecord r:sessions()){
            b.append(csv(r.label)).append(',').append(csv(r.packageName)).append(',').append(r.startedAt).append(',')
                    .append(r.endedAt).append(',').append(r.duration()).append(',').append(r.batteryStart).append(',')
                    .append(r.batteryEnd).append(',').append(Float.isNaN(r.tempMax)?"":r.tempMax).append(',')
                    .append(csv(r.networkStart)).append(',').append(csv(r.networkEnd)).append(',').append(csv(r.profile)).append('\n');
        }
        return b.toString();
    }
    private String csv(String s){return "\"" + (s==null?"":s.replace("\"","\"\"")) + "\"";}

    JSONObject exportProfiles() {
        JSONObject root=new JSONObject();
        try {
            root.put("version",1);
            JSONArray games=new JSONArray();
            Set<String> all=new HashSet<>(); all.addAll(manualGames()); all.addAll(favorites()); all.addAll(pinned());
            for(String pkg:all){
                JSONObject o=new JSONObject();
                o.put("package",pkg);o.put("mode",profileMode(pkg));o.put("dnd",profileDnd(pkg));
                o.put("overlay",profileOverlay(pkg));o.put("volume",profileVolume(pkg));o.put("brightness",profileBrightness(pkg));
                games.put(o);
            }
            root.put("profiles",games);
        } catch(Exception ignored){}
        return root;
    }

    int importProfiles(JSONObject root) {
        int count=0;
        try {
            JSONArray a=root.optJSONArray("profiles"); if(a==null)return 0;
            for(int i=0;i<a.length();i++){
                JSONObject o=a.getJSONObject(i);String pkg=o.optString("package");
                if(pkg.isEmpty())continue;
                saveProfile(pkg,o.optString("mode","Personalizado"),o.optBoolean("dnd",true),
                        o.optBoolean("overlay",false),clamp(o.optInt("volume",80)),clamp(o.optInt("brightness",65)));
                count++;
            }
        }catch(Exception ignored){}
        return count;
    }
    private int clamp(int v){return SessionMath.clampPercent(v);}

    void clearRestoreKeys() {
        p.edit().remove("restore_volume").remove("restore_brightness")
                .remove("restore_brightness_mode").remove("restore_dnd").apply();
    }

    void clearAll() { p.edit().clear().apply(); }
}
