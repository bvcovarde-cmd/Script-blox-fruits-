package com.ghost.gameturbo;

import android.app.ActivityManager;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.BatteryManager;
import android.os.StatFs;

import java.io.BufferedReader;
import java.io.FileReader;
import java.util.List;
import java.util.Locale;

final class DeviceMonitor {
    private long lastCpuTotal = -1, lastCpuIdle = -1;

    String snapshot(Context c) {
        ActivityManager am = (ActivityManager)c.getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
        am.getMemoryInfo(mi);
        long used = Math.max(0L, mi.totalMem - mi.availMem);
        StatFs fs = new StatFs(c.getFilesDir().getAbsolutePath());
        Float cpu = cpu();
        Intent bat = c.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        int pct = -1; float temp = Float.NaN; boolean charging = false;
        if (bat != null) {
            int level = bat.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int scale = bat.getIntExtra(BatteryManager.EXTRA_SCALE, 100);
            pct = scale > 0 ? Math.round(level * 100f / scale) : level;
            int st = bat.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
            charging = st == BatteryManager.BATTERY_STATUS_CHARGING || st == BatteryManager.BATTERY_STATUS_FULL;
            int t = bat.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Integer.MIN_VALUE);
            if (t != Integer.MIN_VALUE) temp = t / 10f;
        }
        float hz = c.getDisplay() == null ? 0f : c.getDisplay().getRefreshRate();
        return "RAM: " + bytes(used) + " usada • " + bytes(mi.availMem) + " livre\n" +
                "Armazenamento livre: " + bytes(fs.getAvailableBytes()) + "\n" +
                "CPU aproximada: " + (cpu == null ? "indisponível" : String.format(Locale.getDefault(), "%.0f%%", cpu)) + "\n" +
                "Temperatura: " + (Float.isNaN(temp) ? "indisponível" : String.format(Locale.getDefault(), "%.1f °C", temp)) + "\n" +
                "Bateria: " + (pct < 0 ? "?" : pct + "%") + (charging ? " • carregando" : "") + "\n" +
                "Rede: " + network(c) + "\n" +
                "Tela: " + (hz <= 0 ? "?" : String.format(Locale.getDefault(), "%.0f Hz", hz)) + "\n" +
                "FPS: indisponível para jogos de terceiros via API pública";
    }

    private Float cpu() {
        try (BufferedReader br = new BufferedReader(new FileReader("/proc/stat"))) {
            String line = br.readLine(); if (line == null || !line.startsWith("cpu ")) return null;
            String[] p = line.trim().split("\\s+");
            long user=Long.parseLong(p[1]), nice=Long.parseLong(p[2]), system=Long.parseLong(p[3]);
            long idle=Long.parseLong(p[4]), wait=p.length>5?Long.parseLong(p[5]):0;
            long irq=p.length>6?Long.parseLong(p[6]):0, soft=p.length>7?Long.parseLong(p[7]):0;
            long total=user+nice+system+idle+wait+irq+soft, idleAll=idle+wait;
            if (lastCpuTotal < 0) { lastCpuTotal=total; lastCpuIdle=idleAll; return null; }
            long td=total-lastCpuTotal, id=idleAll-lastCpuIdle; lastCpuTotal=total; lastCpuIdle=idleAll;
            return td<=0?null:100f*(td-id)/td;
        } catch (Exception e) { return null; }
    }

    static String network(Context c) {
        try {
            ConnectivityManager cm=(ConnectivityManager)c.getSystemService(Context.CONNECTIVITY_SERVICE);
            Network n=cm.getActiveNetwork(); if(n==null)return "sem conexão";
            NetworkCapabilities x=cm.getNetworkCapabilities(n); if(x==null)return "conectado";
            String type=x.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)?"Wi‑Fi":x.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)?"dados móveis":x.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)?"Ethernet":"outra";
            return type+(x.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)?" • internet OK":" • não validada");
        } catch(Exception e){return "indisponível";}
    }

    static boolean hasUsageAccess(Context c) {
        try {
            UsageStatsManager u=(UsageStatsManager)c.getSystemService(Context.USAGE_STATS_SERVICE);
            long now=System.currentTimeMillis(); List<UsageStats> s=u.queryUsageStats(UsageStatsManager.INTERVAL_DAILY,now-60000,now);
            return s!=null&&!s.isEmpty();
        } catch(Exception e){return false;}
    }

    static long weeklyUsage(Context c,String pkg,long fallback) {
        if(!hasUsageAccess(c))return fallback;
        try {
            UsageStatsManager u=(UsageStatsManager)c.getSystemService(Context.USAGE_STATS_SERVICE);
            long end=System.currentTimeMillis(),start=end-7L*24*60*60*1000; long total=0;
            List<UsageStats> list=u.queryUsageStats(UsageStatsManager.INTERVAL_DAILY,start,end);
            if(list!=null)for(UsageStats s:list)if(pkg.equals(s.getPackageName()))total+=s.getTotalTimeInForeground();
            return total>0?total:fallback;
        }catch(Exception e){return fallback;}
    }

    static String bytes(long b){double v=b;String[]u={"B","KB","MB","GB","TB"};int i=0;while(v>=1024&&i<u.length-1){v/=1024;i++;}return v>=100?String.format(Locale.getDefault(),"%.0f %s",v,u[i]):String.format(Locale.getDefault(),"%.1f %s",v,u[i]);}
    static String duration(long ms){long m=Math.max(0,ms)/60000;if(m<1)return"< 1 min";long h=m/60;return h>0?h+"h "+(m%60)+"min":m+"min";}
}
