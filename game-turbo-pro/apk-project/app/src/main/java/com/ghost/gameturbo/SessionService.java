package com.ghost.gameturbo;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;

public class SessionService extends Service {
    private final Handler h=new Handler(Looper.getMainLooper());
    private final DeviceMonitor monitor=new DeviceMonitor();
    private TurboPrefs prefs; private boolean thermalAdjusted;

    private final Runnable tick=new Runnable(){public void run(){
        if(!prefs.hasActiveSession()){stopSelf();return;}
        DeviceMonitor.Sample s=monitor.sample(SessionService.this);prefs.updateActiveTemperature(s.batteryTemp);
        String text=(s.batteryPercent<0?"Bateria ?":s.batteryPercent+"%")+" • "+(Float.isNaN(s.batteryTemp)?"temp ?":String.format(java.util.Locale.getDefault(),"%.1f°C",s.batteryTemp))+" • "+s.network;
        if(!Float.isNaN(s.batteryTemp)&&s.batteryTemp>=45f&&!thermalAdjusted&&Settings.System.canWrite(SessionService.this)){
            try{
                int cur=Settings.System.getInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS,128);
                if(!prefs.has("restore_brightness"))prefs.putInt("restore_brightness",cur);
                Settings.System.putInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS,Math.min(cur,153));
                thermalAdjusted=true;text+=" • proteção térmica: brilho limitado";
            }catch(Exception ignored){}
        }
        notifyState(text);h.postDelayed(this,5000);
    }};

    @Override public void onCreate(){super.onCreate();prefs=new TurboPrefs(this);channel();notifyState("Preparando sessão");tick.run();}
    @Override public int onStartCommand(Intent i,int flags,int id){if(i!=null&&"STOP".equals(i.getAction())){stopSelf();return START_NOT_STICKY;}return START_STICKY;}
    @Override public void onDestroy(){h.removeCallbacksAndMessages(null);super.onDestroy();}
    @Override public IBinder onBind(Intent i){return null;}
    private void notifyState(String text){
        Intent open=new Intent(this,MainActivity.class);open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pi=PendingIntent.getActivity(this,3,open,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        android.app.Notification n=new android.app.Notification.Builder(this,"turbo_session").setSmallIcon(R.drawable.ic_turbo)
                .setContentTitle("Game Turbo Pro • sessão ativa").setContentText(text).setContentIntent(pi).setOngoing(true).build();
        startForeground(2001,n);
    }
    private void channel(){if(Build.VERSION.SDK_INT>=26){NotificationChannel c=new NotificationChannel("turbo_session","Sessão Game Turbo",NotificationManager.IMPORTANCE_LOW);((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(c);}}
}
