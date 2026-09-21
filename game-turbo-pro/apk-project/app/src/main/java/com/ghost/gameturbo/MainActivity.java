package com.ghost.gameturbo;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.NotificationManager;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public class MainActivity extends Activity {
    private static final int BG=Color.rgb(7,10,16),CARD=Color.rgb(17,22,32),CARD2=Color.rgb(24,30,43),TEXT=Color.rgb(239,243,255),MUTED=Color.rgb(153,164,184),PURPLE=Color.rgb(139,92,246),GREEN=Color.rgb(43,213,118),RED=Color.rgb(255,93,115);
    private final Handler handler=new Handler(Looper.getMainLooper());
    private final DeviceMonitor monitor=new DeviceMonitor();
    private TurboPrefs prefs; private LinearLayout gamesBox; private TextView status,stats,history; private boolean leftForGame;
    private final Runnable loop=new Runnable(){public void run(){if(stats!=null)stats.setText(monitor.snapshot(MainActivity.this));handler.postDelayed(this,2500);}};
    static class Game{String pkg,label;boolean detected;Game(String p,String l,boolean d){pkg=p;label=l;detected=d;}}

    @Override protected void onCreate(Bundle b){super.onCreate(b);prefs=new TurboPrefs(this);getWindow().setStatusBarColor(BG);getWindow().setNavigationBarColor(BG);buildUi();loadGames();history.setText(prefs.history());loop.run();}
    @Override protected void onPause(){super.onPause();if(prefs.hasActiveSession())leftForGame=true;}
    @Override protected void onResume(){super.onResume();if(leftForGame){String s=prefs.finishSession();if(s!=null){history.setText(prefs.history());message("Sessão registrada: "+s,GREEN);}leftForGame=false;}}
    @Override protected void onDestroy(){handler.removeCallbacksAndMessages(null);super.onDestroy();}

    private void buildUi(){
        ScrollView sv=new ScrollView(this);sv.setBackgroundColor(BG);LinearLayout root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setPadding(dp(16),dp(20),dp(16),dp(36));sv.addView(root);
        root.addView(text("GAME TURBO PRO",26,TEXT,true));TextView sub=text("Otimização real • sem root • Android 10+",13,MUTED,false);sub.setPadding(0,dp(2),0,dp(14));root.addView(sub);
        status=text("Pronto",13,GREEN,true);root.addView(card(status));root.addView(section("MONITOR DO DISPOSITIVO"));stats=text("Lendo...",13,TEXT,false);stats.setLineSpacing(0,1.25f);root.addView(card(stats));
        root.addView(section("ACESSOS OPCIONAIS"));LinearLayout p=verticalCard();LinearLayout r1=row();r1.addView(button("Uso",PURPLE,v->open(Settings.ACTION_USAGE_ACCESS_SETTINGS,false)),weight());r1.addView(gap());r1.addView(button("Não Perturbe",PURPLE,v->open(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS,false)),weight());p.addView(r1);LinearLayout r2=row();r2.setPadding(0,dp(8),0,0);r2.addView(button("Brilho",PURPLE,v->open(Settings.ACTION_MANAGE_WRITE_SETTINGS,true)),weight());r2.addView(gap());r2.addView(button("Restaurar",RED,v->restore()),weight());p.addView(r2);root.addView(p);
        root.addView(section("MEUS JOGOS"));LinearLayout actions=row();actions.addView(button("+ Adicionar jogo",PURPLE,v->showAdd()),weight());actions.addView(gap());actions.addView(button("Atualizar",CARD2,v->loadGames()),weight());root.addView(actions);gamesBox=new LinearLayout(this);gamesBox.setOrientation(LinearLayout.VERTICAL);gamesBox.setPadding(0,dp(10),0,0);root.addView(gamesBox);
        root.addView(section("HISTÓRICO"));history=text("Nenhuma sessão registrada.",13,MUTED,false);root.addView(card(history));setContentView(sv);
    }

    private void loadGames(){message("Lendo jogos instalados...",MUTED);gamesBox.removeAllViews();new Thread(()->{List<Game> all=apps();Set<String>manual=prefs.manualGames();List<Game> show=new ArrayList<>();for(Game g:all)if(g.detected||manual.contains(g.pkg))show.add(g);Collections.sort(show,Comparator.comparing(x->x.label.toLowerCase(Locale.ROOT)));runOnUiThread(()->{gamesBox.removeAllViews();if(show.isEmpty())gamesBox.addView(card(text("Nenhum jogo detectado. Use Adicionar jogo.",13,MUTED,false)));else for(Game g:show)gamesBox.addView(gameCard(g));message(show.size()+" jogo(s) carregado(s)",GREEN);});}).start();}
    private List<Game> apps(){PackageManager pm=getPackageManager();Intent i=new Intent(Intent.ACTION_MAIN);i.addCategory(Intent.CATEGORY_LAUNCHER);List<ResolveInfo> list=pm.queryIntentActivities(i,PackageManager.MATCH_ALL);Map<String,Game> m=new LinkedHashMap<>();for(ResolveInfo r:list){if(r.activityInfo==null||r.activityInfo.applicationInfo==null)continue;String pkg=r.activityInfo.packageName;if(pkg.equals(getPackageName()))continue;ApplicationInfo ai=r.activityInfo.applicationInfo;String label=String.valueOf(r.loadLabel(pm));m.put(pkg,new Game(pkg,label,ai.category==ApplicationInfo.CATEGORY_GAME));}return new ArrayList<>(m.values());}
    private View gameCard(Game g){LinearLayout b=verticalCard();LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.setMargins(0,0,0,dp(10));b.setLayoutParams(lp);b.addView(text(g.label,17,TEXT,true));TextView info=text(g.pkg+(g.detected?" • jogo detectado":" • manual")+"\n7 dias: "+DeviceMonitor.duration(DeviceMonitor.weeklyUsage(this,g.pkg,prefs.played(g.pkg))),11,MUTED,false);info.setPadding(0,dp(2),0,dp(10));b.addView(info);LinearLayout a=row();a.addView(button("OTIMIZAR",PURPLE,v->optimize(g,false)),weight());a.addView(gap());a.addView(button("INICIAR",GREEN,v->optimize(g,true)),weight());b.addView(a);LinearLayout c=row();c.setPadding(0,dp(8),0,0);c.addView(button("Perfil",CARD2,v->ProfileDialog.show(this,prefs,g.pkg,g.label,()->message("Perfil salvo",GREEN))),weight());if(prefs.manualGames().contains(g.pkg)){c.addView(gap());c.addView(button("Remover",CARD2,v->{Set<String>s=prefs.manualGames();s.remove(g.pkg);prefs.saveManualGames(s);loadGames();}),weight());}b.addView(c);return b;}

    private void showAdd(){new Thread(()->{List<Game> all=apps();Set<String> selected=prefs.manualGames();List<Game> c=new ArrayList<>();for(Game g:all)if(!g.detected&&!selected.contains(g.pkg))c.add(g);Collections.sort(c,Comparator.comparing(x->x.label.toLowerCase(Locale.ROOT)));String[] labels=new String[c.size()];for(int n=0;n<c.size();n++)labels[n]=c.get(n).label;runOnUiThread(()->new AlertDialog.Builder(this).setTitle("Adicionar jogo").setItems(labels,(d,w)->{Set<String>s=prefs.manualGames();s.add(c.get(w).pkg);prefs.saveManualGames(s);loadGames();}).setNegativeButton("Cancelar",null).show());}).start();}

    private void optimize(Game g,boolean launch){List<String> applied=new ArrayList<>();AudioManager a=(AudioManager)getSystemService(AUDIO_SERVICE);if(!prefs.has("restore_volume"))prefs.putInt("restore_volume",a.getStreamVolume(AudioManager.STREAM_MUSIC));int max=a.getStreamMaxVolume(AudioManager.STREAM_MUSIC);a.setStreamVolume(AudioManager.STREAM_MUSIC,Math.round(max*prefs.profileVolume(g.pkg)/100f),0);applied.add("volume");
        if(Settings.System.canWrite(this)){try{if(!prefs.has("restore_brightness")){prefs.putInt("restore_brightness",Settings.System.getInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS,128));prefs.putInt("restore_brightness_mode",Settings.System.getInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS_MODE,Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC));}Settings.System.putInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS_MODE,Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);Settings.System.putInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS,Math.max(1,Math.round(255f*prefs.profileBrightness(g.pkg)/100f)));applied.add("brilho");}catch(Exception ignored){}}
        NotificationManager nm=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);if(prefs.profileDnd(g.pkg)&&nm.isNotificationPolicyAccessGranted()){try{if(!prefs.has("restore_dnd"))prefs.putInt("restore_dnd",nm.getCurrentInterruptionFilter());nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY);applied.add("Não Perturbe");}catch(Exception ignored){}}
        String x=applied.isEmpty()?"Perfil pronto; conceda acessos opcionais para ampliar os ajustes.":"Aplicado: "+TextUtils.join(", ",applied);message(x,GREEN);Toast.makeText(this,x,Toast.LENGTH_SHORT).show();if(launch)launch(g);}
    private void launch(Game g){Intent i=getPackageManager().getLaunchIntentForPackage(g.pkg);if(i==null){message("Não encontrei entrada para "+g.label,RED);return;}prefs.startSession(g.pkg,g.label);leftForGame=false;try{startActivity(i);}catch(Exception e){message("Falha ao iniciar: "+e.getMessage(),RED);}}
    private void restore(){AudioManager a=(AudioManager)getSystemService(AUDIO_SERVICE);if(prefs.has("restore_volume"))a.setStreamVolume(AudioManager.STREAM_MUSIC,prefs.getInt("restore_volume",a.getStreamVolume(AudioManager.STREAM_MUSIC)),0);if(Settings.System.canWrite(this)&&prefs.has("restore_brightness")){try{Settings.System.putInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS_MODE,prefs.getInt("restore_brightness_mode",Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC));Settings.System.putInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS,prefs.getInt("restore_brightness",128));}catch(Exception ignored){}}NotificationManager nm=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);if(nm.isNotificationPolicyAccessGranted()&&prefs.has("restore_dnd")){try{nm.setInterruptionFilter(prefs.getInt("restore_dnd",NotificationManager.INTERRUPTION_FILTER_ALL));}catch(Exception ignored){}}prefs.clearRestoreKeys();message("Configurações restauradas",GREEN);}
    private void open(String action,boolean pkg){Intent i=new Intent(action);if(pkg)i.setData(Uri.parse("package:"+getPackageName()));try{startActivity(i);}catch(ActivityNotFoundException e){startActivity(new Intent(Settings.ACTION_SETTINGS));}}

    private void message(String s,int color){status.setText(s);status.setTextColor(color);}private TextView section(String s){TextView t=text(s,12,MUTED,true);t.setPadding(0,dp(20),0,dp(8));return t;}private TextView text(String s,int sp,int color,boolean bold){TextView t=new TextView(this);t.setText(s);t.setTextSize(sp);t.setTextColor(color);if(bold)t.setTypeface(android.graphics.Typeface.DEFAULT,android.graphics.Typeface.BOLD);return t;}private LinearLayout verticalCard(){LinearLayout l=new LinearLayout(this);l.setOrientation(LinearLayout.VERTICAL);l.setPadding(dp(14),dp(12),dp(14),dp(12));l.setBackground(round(CARD,18));return l;}private View card(View child){LinearLayout l=verticalCard();l.addView(child);return l;}private LinearLayout row(){LinearLayout l=new LinearLayout(this);l.setOrientation(LinearLayout.HORIZONTAL);l.setGravity(Gravity.CENTER_VERTICAL);return l;}private View gap(){View v=new View(this);v.setLayoutParams(new LinearLayout.LayoutParams(dp(8),1));return v;}private LinearLayout.LayoutParams weight(){return new LinearLayout.LayoutParams(0,dp(44),1f);}private Button button(String s,int color,View.OnClickListener x){Button b=new Button(this);b.setText(s);b.setTextColor(TEXT);b.setTextSize(12);b.setAllCaps(false);b.setBackground(round(color,14));b.setOnClickListener(x);return b;}private GradientDrawable round(int color,int r){GradientDrawable g=new GradientDrawable();g.setColor(color);g.setCornerRadius(dp(r));return g;}private int dp(int v){return Math.round(v*getResources().getDisplayMetrics().density);}
}
