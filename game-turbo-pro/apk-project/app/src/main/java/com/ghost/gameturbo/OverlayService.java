package com.ghost.gameturbo;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.TextView;

public class OverlayService extends Service {
    private final Handler h=new Handler(Looper.getMainLooper());
    private WindowManager wm; private TextView bubble; private TurboPrefs prefs;
    private final DeviceMonitor monitor=new DeviceMonitor();

    private final Runnable tick=new Runnable(){public void run(){
        if(bubble!=null){
            DeviceMonitor.Sample s=monitor.sample(OverlayService.this);
            long elapsed=Math.max(0,System.currentTimeMillis()-prefs.activeStart());
            bubble.setText("⚡ "+DeviceMonitor.duration(elapsed)+"  •  "+(s.batteryPercent<0?"?":s.batteryPercent+"%")+"\n"+
                    (Float.isNaN(s.batteryTemp)?"Temp ?":String.format(java.util.Locale.getDefault(),"%.1f°C",s.batteryTemp))+"  •  "+s.network);
            prefs.updateActiveTemperature(s.batteryTemp);
        }
        h.postDelayed(this,2500);
    }};

    @Override public void onCreate(){
        super.onCreate();prefs=new TurboPrefs(this);channel();
        Intent open=new Intent(this,MainActivity.class);open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pi=PendingIntent.getActivity(this,2,open,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        android.app.Notification n=new android.app.Notification.Builder(this,"turbo_overlay")
                .setSmallIcon(com.ghost.gameturbo.R.drawable.ic_turbo).setContentTitle("Game Turbo Pro")
                .setContentText("Overlay da sessão ativo").setContentIntent(pi).setOngoing(true).build();
        startForeground(2002,n);
        if(!Settings.canDrawOverlays(this)){stopSelf();return;}
        wm=(WindowManager)getSystemService(WINDOW_SERVICE);
        bubble=new TextView(this);bubble.setTextColor(Color.WHITE);bubble.setTextSize(12);bubble.setGravity(Gravity.CENTER);
        bubble.setPadding(dp(12),dp(8),dp(12),dp(8));
        android.graphics.drawable.GradientDrawable bg=new android.graphics.drawable.GradientDrawable();bg.setColor(0xD9181E2B);bg.setCornerRadius(dp(14));bubble.setBackground(bg);
        bubble.setOnClickListener(v->{try{startActivity(open);}catch(Exception ignored){}});
        WindowManager.LayoutParams lp=new WindowManager.LayoutParams(WindowManager.LayoutParams.WRAP_CONTENT,WindowManager.LayoutParams.WRAP_CONTENT,
                Build.VERSION.SDK_INT>=26?WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY:WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE|WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,PixelFormat.TRANSLUCENT);
        lp.gravity=Gravity.TOP|Gravity.END;lp.x=dp(12);lp.y=dp(90);
        wm.addView(bubble,lp);tick.run();
    }
    @Override public int onStartCommand(Intent i,int flags,int id){return START_STICKY;}
    @Override public void onDestroy(){h.removeCallbacksAndMessages(null);if(wm!=null&&bubble!=null)try{wm.removeView(bubble);}catch(Exception ignored){}super.onDestroy();}
    @Override public IBinder onBind(Intent i){return null;}
    private void channel(){if(Build.VERSION.SDK_INT>=26){NotificationChannel c=new NotificationChannel("turbo_overlay","Game Turbo Overlay",NotificationManager.IMPORTANCE_LOW);((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(c);}}
    private int dp(int v){return Math.round(v*getResources().getDisplayMetrics().density);}
}
