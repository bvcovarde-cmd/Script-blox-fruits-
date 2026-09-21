package com.ghost.gameturbo;

import android.app.ActivityManager;
import android.app.NotificationManager;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.BatteryManager;
import android.os.Build;
import android.os.PowerManager;
import android.os.StatFs;
import android.provider.Settings;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.net.Inet4Address;
import java.net.NetworkInterface;
import java.net.Socket;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

final class DeviceMonitor {
    static final class Sample {
        long ramUsed, ramTotal, ramAvailable, storageAvailable, storageTotal;
        Float cpuPercent;
        int cpuCores;
        long cpuMaxKhz;
        int batteryPercent = -1;
        float batteryTemp = Float.NaN;
        String batteryHealth = "indisponível";
        String charging = "";
        String thermal = "indisponível";
        String network = "sem conexão";
        boolean networkValidated;
        boolean networkMetered;
        float refreshHz;
    }

    private long lastCpuTotal = -1, lastCpuIdle = -1;

    Sample sample(Context c) {
        Sample s=new Sample();
        ActivityManager am=(ActivityManager)c.getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo mi=new ActivityManager.MemoryInfo();am.getMemoryInfo(mi);
        s.ramTotal=mi.totalMem;s.ramAvailable=mi.availMem;s.ramUsed=Math.max(0,s.ramTotal-s.ramAvailable);
        StatFs fs=new StatFs(c.getFilesDir().getAbsolutePath());s.storageAvailable=fs.getAvailableBytes();s.storageTotal=fs.getTotalBytes();
        s.cpuPercent=cpu();s.cpuCores=Runtime.getRuntime().availableProcessors();s.cpuMaxKhz=cpuMaxKhz();
        Intent bat=c.registerReceiver(null,new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if(bat!=null){
            int level=bat.getIntExtra(BatteryManager.EXTRA_LEVEL,-1),scale=bat.getIntExtra(BatteryManager.EXTRA_SCALE,100);
            s.batteryPercent=scale>0?Math.round(level*100f/scale):level;
            int t=bat.getIntExtra(BatteryManager.EXTRA_TEMPERATURE,Integer.MIN_VALUE);if(t!=Integer.MIN_VALUE)s.batteryTemp=t/10f;
            int h=bat.getIntExtra(BatteryManager.EXTRA_HEALTH,-1);s.batteryHealth=health(h);
            int plug=bat.getIntExtra(BatteryManager.EXTRA_PLUGGED,0);
            if(plug==BatteryManager.BATTERY_PLUGGED_AC)s.charging=" • AC";
            else if(plug==BatteryManager.BATTERY_PLUGGED_USB)s.charging=" • USB";
            else if(plug==BatteryManager.BATTERY_PLUGGED_WIRELESS)s.charging=" • sem fio";
        }
        try{
            PowerManager pm=(PowerManager)c.getSystemService(Context.POWER_SERVICE);
            if(Build.VERSION.SDK_INT>=29)s.thermal=thermal(pm.getCurrentThermalStatus());
        }catch(Exception ignored){}
        ConnectivityManager cm=(ConnectivityManager)c.getSystemService(Context.CONNECTIVITY_SERVICE);
        try{
            Network n=cm.getActiveNetwork();NetworkCapabilities x=n==null?null:cm.getNetworkCapabilities(n);
            if(x!=null){
                String type=x.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)?"Wi‑Fi":x.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)?"dados móveis":x.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)?"Ethernet":x.hasTransport(NetworkCapabilities.TRANSPORT_VPN)?"VPN":"outra";
                s.networkValidated=x.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED);s.networkMetered=!x.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED);
                s.network=type+(s.networkValidated?" • internet OK":" • não validada")+(s.networkMetered?" • medida":"");
            }
        }catch(Exception ignored){}
        s.refreshHz=c.getDisplay()==null?0f:c.getDisplay().getRefreshRate();
        return s;
    }

    String snapshot(Context c) {
        Sample s=sample(c);
        int ramPct=s.ramTotal>0?Math.round(s.ramUsed*100f/s.ramTotal):0;
        int diskPct=s.storageTotal>0?Math.round((s.storageTotal-s.storageAvailable)*100f/s.storageTotal):0;
        return "RAM: "+bytes(s.ramUsed)+" / "+bytes(s.ramTotal)+" ("+ramPct+"%) • livre "+bytes(s.ramAvailable)+"\n"+
                "Armazenamento: "+diskPct+"% usado • livre "+bytes(s.storageAvailable)+"\n"+
                "CPU: "+(s.cpuPercent==null?"indisponível":String.format(Locale.getDefault(),"%.0f%%",s.cpuPercent))+
                " • "+s.cpuCores+" núcleos"+(s.cpuMaxKhz>0?" • máx "+String.format(Locale.getDefault(),"%.2f GHz",s.cpuMaxKhz/1_000_000f):"")+"\n"+
                "Bateria: "+(s.batteryPercent<0?"?":s.batteryPercent+"%")+s.charging+" • saúde "+s.batteryHealth+"\n"+
                "Temperatura: "+(Float.isNaN(s.batteryTemp)?"indisponível":String.format(Locale.getDefault(),"%.1f °C",s.batteryTemp))+" • térmico "+s.thermal+"\n"+
                "Rede: "+s.network+"\n"+
                "Tela: "+(s.refreshHz<=0?"?":String.format(Locale.getDefault(),"%.0f Hz",s.refreshHz))+" • FPS de outro app: indisponível via API pública";
    }

    String compatibility(Context c) {
        NotificationManager nm=(NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE);
        Sample s=sample(c);
        return "Uso de apps: "+yes(hasUsageAccess(c))+"\n"+
                "Não Perturbe: "+yes(nm.isNotificationPolicyAccessGranted())+"\n"+
                "Alterar brilho: "+yes(Settings.System.canWrite(c))+"\n"+
                "Sobre outros apps: "+yes(Settings.canDrawOverlays(c))+"\n"+
                "Temperatura: "+yes(!Float.isNaN(s.batteryTemp))+"\n"+
                "Estado térmico: "+yes(!"indisponível".equals(s.thermal))+"\n"+
                "Rede validada: "+yes(s.networkValidated)+"\n"+
                "Taxa de atualização: "+yes(s.refreshHz>0)+"\n"+
                "FPS de terceiros: NÃO • Android não expõe API pública genérica\n"+
                "Controle de CPU/GPU de terceiros: NÃO • requer sistema/OEM/root";
    }

    static String dns(Context c) {
        try{
            ConnectivityManager cm=(ConnectivityManager)c.getSystemService(Context.CONNECTIVITY_SERVICE);Network n=cm.getActiveNetwork();if(n==null)return"indisponível";
            LinkProperties lp=cm.getLinkProperties(n);if(lp==null||lp.getDnsServers().isEmpty())return"indisponível";
            StringBuilder b=new StringBuilder();for(int i=0;i<lp.getDnsServers().size();i++){if(i>0)b.append(", ");b.append(lp.getDnsServers().get(i).getHostAddress());}return b.toString();
        }catch(Exception e){return"indisponível";}
    }

    static String localIpv4() {
        try{for(NetworkInterface ni:Collections.list(NetworkInterface.getNetworkInterfaces()))for(java.net.InetAddress a:Collections.list(ni.getInetAddresses()))if(!a.isLoopbackAddress()&&a instanceof Inet4Address)return a.getHostAddress();}catch(Exception ignored){}
        return "indisponível";
    }

    static String latencyTest() {
        int[] values=new int[5];int ok=0;long sum=0;int min=Integer.MAX_VALUE,max=0;
        for(int i=0;i<5;i++){
            long st=System.nanoTime();
            try(Socket socket=new Socket()){
                socket.connect(new java.net.InetSocketAddress("1.1.1.1",443),1500);
                int ms=(int)((System.nanoTime()-st)/1_000_000L);values[i]=ms;ok++;sum+=ms;min=Math.min(min,ms);max=Math.max(max,ms);
            }catch(Exception ignored){values[i]=-1;}
        }
        if(ok==0)return"Falha nas 5 tentativas.";
        return "Cloudflare 1.1.1.1:443 • mín "+min+" ms • média "+(sum/ok)+" ms • máx "+max+" ms • perda "+((5-ok)*20)+"%\nObs.: isto mede o servidor de teste, não o servidor do jogo.";
    }

    private Float cpu() {
        try(BufferedReader br=new BufferedReader(new FileReader("/proc/stat"))){
            String line=br.readLine();if(line==null||!line.startsWith("cpu "))return null;String[] p=line.trim().split("\\s+");
            long user=Long.parseLong(p[1]),nice=Long.parseLong(p[2]),system=Long.parseLong(p[3]),idle=Long.parseLong(p[4]),wait=p.length>5?Long.parseLong(p[5]):0,irq=p.length>6?Long.parseLong(p[6]):0,soft=p.length>7?Long.parseLong(p[7]):0;
            long total=user+nice+system+idle+wait+irq+soft,idleAll=idle+wait;if(lastCpuTotal<0){lastCpuTotal=total;lastCpuIdle=idleAll;return null;}
            long td=total-lastCpuTotal,id=idleAll-lastCpuIdle;lastCpuTotal=total;lastCpuIdle=idleAll;return td<=0?null:100f*(td-id)/td;
        }catch(Exception e){return null;}
    }
    private long cpuMaxKhz(){long max=0;for(int i=0;i<Runtime.getRuntime().availableProcessors();i++){File f=new File("/sys/devices/system/cpu/cpu"+i+"/cpufreq/cpuinfo_max_freq");try(BufferedReader b=new BufferedReader(new FileReader(f))){max=Math.max(max,Long.parseLong(b.readLine().trim()));}catch(Exception ignored){}}return max;}
    static boolean hasUsageAccess(Context c){try{UsageStatsManager u=(UsageStatsManager)c.getSystemService(Context.USAGE_STATS_SERVICE);long now=System.currentTimeMillis();List<UsageStats>s=u.queryUsageStats(UsageStatsManager.INTERVAL_DAILY,now-60000,now);return s!=null&&!s.isEmpty();}catch(Exception e){return false;}}
    static long weeklyUsage(Context c,String pkg,long fallback){if(!hasUsageAccess(c))return fallback;try{UsageStatsManager u=(UsageStatsManager)c.getSystemService(Context.USAGE_STATS_SERVICE);long end=System.currentTimeMillis(),start=end-7L*24*60*60*1000,total=0;List<UsageStats>list=u.queryUsageStats(UsageStatsManager.INTERVAL_DAILY,start,end);if(list!=null)for(UsageStats s:list)if(pkg.equals(s.getPackageName()))total+=s.getTotalTimeInForeground();return total>0?total:fallback;}catch(Exception e){return fallback;}}
    static String network(Context c){return new DeviceMonitor().sample(c).network;}
    static String bytes(long b){double v=b;String[]u={"B","KB","MB","GB","TB"};int i=0;while(v>=1024&&i<u.length-1){v/=1024;i++;}return v>=100?String.format(Locale.getDefault(),"%.0f %s",v,u[i]):String.format(Locale.getDefault(),"%.1f %s",v,u[i]);}
    static String duration(long ms){long m=Math.max(0,ms)/60000;if(m<1)return"< 1 min";long h=m/60;return h>0?h+"h "+(m%60)+"min":m+"min";}
    private static String yes(boolean v){return v?"SIM":"NÃO";}
    private static String thermal(int s){switch(s){case 0:return"nenhum";case 1:return"leve";case 2:return"moderado";case 3:return"severo";case 4:return"crítico";case 5:return"emergência";case 6:return"desligamento";default:return"indisponível";}}
    private static String health(int h){switch(h){case BatteryManager.BATTERY_HEALTH_GOOD:return"boa";case BatteryManager.BATTERY_HEALTH_OVERHEAT:return"superaquecida";case BatteryManager.BATTERY_HEALTH_COLD:return"fria";case BatteryManager.BATTERY_HEALTH_DEAD:return"degradada";case BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE:return"sobretensão";default:return"desconhecida";}}
}
