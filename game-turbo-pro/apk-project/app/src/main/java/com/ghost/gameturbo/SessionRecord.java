package com.ghost.gameturbo;

import org.json.JSONException;
import org.json.JSONObject;

final class SessionRecord {
    String packageName;
    String label;
    long startedAt;
    long endedAt;
    int batteryStart = -1;
    int batteryEnd = -1;
    float tempStart = Float.NaN;
    float tempMax = Float.NaN;
    String networkStart = "";
    String networkEnd = "";
    String profile = "Personalizado";

    long duration() { return Math.max(0L, endedAt - startedAt); }

    JSONObject json() throws JSONException {
        JSONObject o = new JSONObject();
        o.put("package", packageName);
        o.put("label", label);
        o.put("startedAt", startedAt);
        o.put("endedAt", endedAt);
        o.put("durationMs", duration());
        o.put("batteryStart", batteryStart);
        o.put("batteryEnd", batteryEnd);
        o.put("tempStart", Float.isNaN(tempStart) ? JSONObject.NULL : tempStart);
        o.put("tempMax", Float.isNaN(tempMax) ? JSONObject.NULL : tempMax);
        o.put("networkStart", networkStart);
        o.put("networkEnd", networkEnd);
        o.put("profile", profile);
        return o;
    }

    static SessionRecord from(JSONObject o) {
        SessionRecord r = new SessionRecord();
        r.packageName = o.optString("package");
        r.label = o.optString("label", r.packageName);
        r.startedAt = o.optLong("startedAt");
        r.endedAt = o.optLong("endedAt");
        r.batteryStart = o.optInt("batteryStart", -1);
        r.batteryEnd = o.optInt("batteryEnd", -1);
        r.tempStart = o.isNull("tempStart") ? Float.NaN : (float)o.optDouble("tempStart", Double.NaN);
        r.tempMax = o.isNull("tempMax") ? Float.NaN : (float)o.optDouble("tempMax", Double.NaN);
        r.networkStart = o.optString("networkStart");
        r.networkEnd = o.optString("networkEnd");
        r.profile = o.optString("profile", "Personalizado");
        return r;
    }
}
