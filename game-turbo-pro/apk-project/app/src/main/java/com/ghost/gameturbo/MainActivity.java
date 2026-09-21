package com.ghost.gameturbo;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.NotificationManager;
import android.content.pm.ShortcutInfo;
import android.content.pm.ShortcutManager;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.Icon;
import android.media.AudioManager;
import android.media.projection.MediaProjectionManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.StrictMode;
import android.provider.Settings;
import android.text.Editable;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public class MainActivity extends Activity {
    private static final int BG=Color.rgb(7,10,16),CARD=Color.rgb(17,22,32),CARD2=Color.rgb(24,30,43),
            TEXT=Color.rgb(239,243,255),MUTED=Color.rgb(153,164,184),PURPLE=Color.rgb(139,92,246),
            GREEN=Color.rgb(43,213,118),RED=Color.rgb(255,93,115),AMBER=Color.rgb(245,179,66);

    private static final int RC_CAPTURE=401,RC_EXPORT_CSV=402,RC_EXPORT_JSON=403,RC_EXPORT_PROFILES=404,RC_IMPORT_PROFILES=405;

    private final Handler handler=new Handler(Looper.getMainLooper());
    private final DeviceMonitor monitor=new DeviceMonitor();
    private TurboPrefs prefs;
    private LinearLayout gamesBox;
    private TextView status,stats,history,permissionStatus,networkInfo,ranking,activeSession;
    private EditText search;
    private SimpleGraphView graph;
    private boolean leftForGame;
    private String pendingCaptureAction=CaptureService.ACTION_CAPTURE;
    private int filterMode=0,sortMode=0;
    private List<Game> loadedGames=new ArrayList<>();
    private String shortcutPackage;

    private final Runnable loop=new Runnable(){public void run(){
        if(stats!=null)stats.setText(monitor.snapshot(MainActivity.this));
        if(permissionStatus!=null)permissionStatus.setText(permissionSummary());
        if(activeSession!=null)activeSession.setText(sessionStatus());
        handler.postDelayed(this,3000);
    }};

    static class Game {
        String pkg,label;boolean detected;long installedAt;Drawable icon;
        Game(String p,String l,boolean d,long at,Drawable i){pkg=p;label=l;detected=d;installedAt=at;icon=i;}
    }

    @Override protected void onCreate(Bundle b){
        super.onCreate(b);
        if((getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE)!=0) StrictMode.setThreadPolicy(new StrictMode.ThreadPolicy.Builder().detectAll().penaltyLog().build());
        prefs=new TurboPrefs(this);
        getWindow().setStatusBarColor(BG);getWindow().setNavigationBarColor(BG);
        shortcutPackage=getIntent().getStringExtra("launch_pkg");
        buildUi();
        loadGames();
        refreshAnalytics();
        recoverSessionIfNeeded();
        loop.run();
    }

    @Override protected void onNewIntent(Intent i){
        super.onNewIntent(i);setIntent(i);String pkg=i.getStringExtra("launch_pkg");
        if(!TextUtils.isEmpty(pkg)){shortcutPackage=pkg;launchShortcutWhenReady();}
    }

    @Override protected void onPause(){super.onPause();if(prefs.hasActiveSession())leftForGame=true;}

    @Override protected void onResume(){
        super.onResume();
        if(leftForGame&&prefs.hasActiveSession()){
            finishActiveSession("retorno ao Game Turbo");
            leftForGame=false;
        }
    }

    @Override protected void onDestroy(){handler.removeCallbacksAndMessages(null);super.onDestroy();}

    private void buildUi(){
        ScrollView sv=new ScrollView(this);sv.setBackgroundColor(BG);
        LinearLayout root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setPadding(dp(16),dp(20),dp(16),dp(40));sv.addView(root);

        root.addView(text("GAME TURBO PRO",28,TEXT,true));
        TextView sub=text("2026.09.200 • sem root • funções reais do Android",13,MUTED,false);sub.setPadding(0,dp(2),0,dp(14));root.addView(sub);

        status=text("Pronto",13,GREEN,true);root.addView(card(status));
        activeSession=text("Nenhuma sessão ativa",12,MUTED,false);LinearLayout sessionCard=verticalCard();sessionCard.setPadding(dp(14),dp(10),dp(14),dp(10));sessionCard.addView(activeSession);
        Button finish=button("Finalizar sessão e restaurar",CARD2,v->finishActiveSession("finalizada pelo usuário"));finish.setVisibility(View.GONE);
        activeSession.setOnClickListener(v->{finish.setVisibility(prefs.hasActiveSession()?View.VISIBLE:View.GONE);});
        sessionCard.addView(finish);root.addView(spacer(8));root.addView(sessionCard);

        root.addView(section("PAINEL DO DISPOSITIVO"));
        stats=text("Lendo...",13,TEXT,false);stats.setLineSpacing(0,1.2f);root.addView(card(stats));

        root.addView(section("PERMISSÕES E COMPATIBILIDADE"));
        permissionStatus=text(permissionSummary(),12,MUTED,false);root.addView(card(permissionStatus));
        LinearLayout p1=row();
        p1.addView(button("Uso",PURPLE,v->open(Settings.ACTION_USAGE_ACCESS_SETTINGS,false)),weight());p1.addView(gap());
        p1.addView(button("DND",PURPLE,v->open(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS,false)),weight());p1.addView(gap());
        p1.addView(button("Brilho",PURPLE,v->open(Settings.ACTION_MANAGE_WRITE_SETTINGS,true)),weight());root.addView(p1);
        LinearLayout p2=row();p2.setPadding(0,dp(8),0,0);
        p2.addView(button("Overlay",PURPLE,v->open(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,true)),weight());p2.addView(gap());
        p2.addView(button("Notificações",CARD2,v->requestNotifications()),weight());p2.addView(gap());
        p2.addView(button("Compatibilidade",CARD2,v->showCompatibility()),weight());root.addView(p2);

        root.addView(section("FERRAMENTAS DE SESSÃO"));
        LinearLayout t1=row();
        t1.addView(button("Captura",PURPLE,v->requestProjection(CaptureService.ACTION_CAPTURE)),weight());t1.addView(gap());
        t1.addView(button("Gravar tela",PURPLE,v->requestProjection(CaptureService.ACTION_RECORD)),weight());t1.addView(gap());
        t1.addView(button("Restaurar",RED,v->restore()),weight());root.addView(t1);
        TextView captureNote=text("Captura e gravação usam a autorização oficial MediaProjection do Android. A gravação desta versão é de vídeo da tela, sem áudio interno.",11,MUTED,false);
        captureNote.setPadding(0,dp(6),0,0);root.addView(captureNote);

        root.addView(section("DIAGNÓSTICO DE REDE"));
        networkInfo=text(networkDetails(),12,TEXT,false);root.addView(card(networkInfo));
        LinearLayout nr=row();
        nr.addView(button("Atualizar",CARD2,v->networkInfo.setText(networkDetails())),weight());nr.addView(gap());
        nr.addView(button("Teste de latência",PURPLE,v->runLatency()),weight());root.addView(nr);

        root.addView(section("MEUS JOGOS"));
        search=new EditText(this);search.setHint("Pesquisar jogo ou pacote");search.setHintTextColor(MUTED);search.setTextColor(TEXT);search.setSingleLine(true);
        search.setPadding(dp(12),0,dp(12),0);search.setBackground(round(CARD,14));root.addView(search,new LinearLayout.LayoutParams(-1,dp(48)));
        search.addTextChangedListener(new TextWatcher(){public void beforeTextChanged(CharSequence s,int st,int c,int a){}public void onTextChanged(CharSequence s,int st,int before,int count){renderGames();}public void afterTextChanged(Editable e){}});

        LinearLayout filters=row();filters.setPadding(0,dp(8),0,0);
        filters.addView(button("Todos",CARD2,v->{filterMode=0;renderGames();}),weight());filters.addView(gap());
        filters.addView(button("Favoritos",CARD2,v->{filterMode=1;renderGames();}),weight());filters.addView(gap());
        filters.addView(button("Recentes",CARD2,v->{filterMode=2;renderGames();}),weight());root.addView(filters);

        LinearLayout actions=row();actions.setPadding(0,dp(8),0,0);
        actions.addView(button("+ Adicionar",PURPLE,v->showAdd()),weight());actions.addView(gap());
        actions.addView(button("Ordenar",CARD2,v->cycleSort()),weight());actions.addView(gap());
        actions.addView(button("Atualizar",CARD2,v->loadGames()),weight());root.addView(actions);

        gamesBox=new LinearLayout(this);gamesBox.setOrientation(LinearLayout.VERTICAL);gamesBox.setPadding(0,dp(10),0,0);root.addView(gamesBox);

        root.addView(section("ANÁLISE DE USO"));
        graph=new SimpleGraphView(this);graph.setBackground(round(CARD,18));root.addView(graph,new LinearLayout.LayoutParams(-1,dp(170)));
        ranking=text("",12,TEXT,false);ranking.setPadding(0,dp(8),0,0);root.addView(card(ranking));

        root.addView(section("HISTÓRICO"));
        history=text("Nenhuma sessão registrada.",12,MUTED,false);root.addView(card(history));
        LinearLayout h1=row();h1.setPadding(0,dp(8),0,0);
        h1.addView(button("Gerenciar",CARD2,v->manageHistory()),weight());h1.addView(gap());
        h1.addView(button("CSV",PURPLE,v->createDocument("text/csv","GameTurboPro_sessoes.csv",RC_EXPORT_CSV)),weight());h1.addView(gap());
        h1.addView(button("JSON",PURPLE,v->createDocument("application/json","GameTurboPro_sessoes.json",RC_EXPORT_JSON)),weight());root.addView(h1);

        root.addView(section("PERFIS E BACKUP"));
        LinearLayout b1=row();
        b1.addView(button("Exportar perfis",PURPLE,v->createDocument("application/json","GameTurboPro_perfis.json",RC_EXPORT_PROFILES)),weight());b1.addView(gap());
        b1.addView(button("Importar perfis",CARD2,v->openProfileImport()),weight());b1.addView(gap());
        b1.addView(button("Relatório BOOST",CARD2,v->showBoostReport()),weight());root.addView(b1);

        root.addView(section("PRIVACIDADE E DADOS"));
        TextView privacy=text("Histórico, perfis e biblioteca ficam localmente no aparelho. O teste de latência só abre conexões manuais para 1.1.1.1:443. Nenhuma lista de apps é enviada pelo Game Turbo Pro.",11,MUTED,false);root.addView(card(privacy));
        LinearLayout d1=row();d1.setPadding(0,dp(8),0,0);
        d1.addView(button("Limpar histórico",CARD2,v->confirmClearHistory()),weight());d1.addView(gap());
        d1.addView(button("Apagar todos os dados",RED,v->confirmClearAll()),weight());root.addView(d1);

        setContentView(sv);
    }

    private void loadGames(){
        message("Lendo jogos instalados...",MUTED);gamesBox.removeAllViews();
        new Thread(()->{
            List<Game> all=apps();
            Set<String>manual=prefs.manualGames(),installed=new HashSet<>();
            for(Game g:all)installed.add(g.pkg);
            manual.retainAll(installed);prefs.saveManualGames(manual);
            List<Game> show=new ArrayList<>();for(Game g:all)if(g.detected||manual.contains(g.pkg))show.add(g);
            runOnUiThread(()->{loadedGames=show;renderGames();message(show.size()+" jogo(s) carregado(s)",GREEN);launchShortcutWhenReady();});
        }).start();
    }

    private List<Game> apps(){
        PackageManager pm=getPackageManager();Intent i=new Intent(Intent.ACTION_MAIN);i.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> list=pm.queryIntentActivities(i,PackageManager.MATCH_ALL);Map<String,Game> m=new LinkedHashMap<>();
        for(ResolveInfo r:list){
            if(r.activityInfo==null||r.activityInfo.applicationInfo==null)continue;
            String pkg=r.activityInfo.packageName;if(pkg.equals(getPackageName()))continue;
            ApplicationInfo ai=r.activityInfo.applicationInfo;String label=String.valueOf(r.loadLabel(pm));long at=0;
            try{at=pm.getPackageInfo(pkg,0).firstInstallTime;}catch(Exception ignored){}
            Drawable icon;try{icon=r.loadIcon(pm);}catch(Exception e){icon=getDrawable(R.drawable.ic_turbo);}
            m.put(pkg,new Game(pkg,label,ai.category==ApplicationInfo.CATEGORY_GAME,at,icon));
        }
        return new ArrayList<>(m.values());
    }

    private void renderGames(){
        if(gamesBox==null)return;String q=search==null?"":search.getText().toString().trim().toLowerCase(Locale.ROOT);
        Set<String> fav=prefs.favorites(),pin=prefs.pinned();long recentCut=System.currentTimeMillis()-30L*24*60*60*1000;
        List<Game> list=new ArrayList<>();
        for(Game g:loadedGames){
            if(!q.isEmpty()&&!g.label.toLowerCase(Locale.ROOT).contains(q)&&!g.pkg.toLowerCase(Locale.ROOT).contains(q))continue;
            if(filterMode==1&&!fav.contains(g.pkg))continue;
            if(filterMode==2&&g.installedAt<recentCut)continue;
            list.add(g);
        }
        Comparator<Game> comp;
        if(sortMode==1)comp=(a,b)->Long.compare(prefs.played(b.pkg),prefs.played(a.pkg));
        else if(sortMode==2)comp=(a,b)->Long.compare(b.installedAt,a.installedAt);
        else comp=Comparator.comparing(a->a.label.toLowerCase(Locale.ROOT));
        Collections.sort(list,(a,b)->{boolean pa=pin.contains(a.pkg),pb=pin.contains(b.pkg);if(pa!=pb)return pa?-1:1;return comp.compare(a,b);});
        gamesBox.removeAllViews();
        if(list.isEmpty())gamesBox.addView(card(text("Nenhum jogo neste filtro.",13,MUTED,false)));
        else for(Game g:list)gamesBox.addView(gameCard(g));
    }

    private View gameCard(Game g){
        LinearLayout b=verticalCard();LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.setMargins(0,0,0,dp(10));b.setLayoutParams(lp);
        LinearLayout top=row();ImageView iv=new ImageView(this);iv.setImageDrawable(g.icon);iv.setScaleType(ImageView.ScaleType.CENTER_INSIDE);top.addView(iv,new LinearLayout.LayoutParams(dp(48),dp(48)));
        LinearLayout names=new LinearLayout(this);names.setOrientation(LinearLayout.VERTICAL);names.setPadding(dp(10),0,0,0);
        names.addView(text(g.label,17,TEXT,true));names.addView(text(g.pkg,10,MUTED,false));top.addView(names,new LinearLayout.LayoutParams(0,-2,1f));b.addView(top);

        long total=prefs.played(g.pkg),week=DeviceMonitor.weeklyUsage(this,g.pkg,total),today=todayPlayed(g.pkg),last=lastPlayed(g.pkg);
        String meta=(g.detected?"Detectado como jogo":"Adicionado manualmente")+" • "+prefs.profileMode(g.pkg)+"\nHoje: "+DeviceMonitor.duration(today)+" • 7 dias: "+DeviceMonitor.duration(week)+" • total local: "+DeviceMonitor.duration(total);
        if(last>0)meta+="\nÚltima sessão: "+DateFormat.getDateTimeInstance(DateFormat.SHORT,DateFormat.SHORT).format(new java.util.Date(last));
        TextView info=text(meta,11,MUTED,false);info.setPadding(0,dp(6),0,dp(10));b.addView(info);

        LinearLayout a=row();a.addView(button("OTIMIZAR",PURPLE,v->optimize(g,false)),weight());a.addView(gap());a.addView(button("INICIAR",GREEN,v->optimize(g,true)),weight());b.addView(a);
        LinearLayout c=row();c.setPadding(0,dp(8),0,0);
        c.addView(button("Perfil",CARD2,v->ProfileDialog.show(this,prefs,g.pkg,g.label,()->{message("Perfil salvo",GREEN);renderGames();})),weight());c.addView(gap());
        c.addView(button(prefs.favorites().contains(g.pkg)?"★ Favorito":"☆ Favorito",CARD2,v->toggleSet(g.pkg,prefs.favorites(),true)),weight());c.addView(gap());
        c.addView(button(prefs.pinned().contains(g.pkg)?"📌 Fixado":"Fixar",CARD2,v->toggleSet(g.pkg,prefs.pinned(),false)),weight());b.addView(c);
        LinearLayout d=row();d.setPadding(0,dp(8),0,0);
        d.addView(button("Atalho",CARD2,v->pinShortcut(g)),weight());
        if(prefs.manualGames().contains(g.pkg)){d.addView(gap());d.addView(button("Remover",CARD2,v->{Set<String>s=prefs.manualGames();s.remove(g.pkg);prefs.saveManualGames(s);loadGames();}),weight());}
        b.addView(d);return b;
    }

    private void toggleSet(String pkg,Set<String>s,boolean favorite){if(s.contains(pkg))s.remove(pkg);else s.add(pkg);if(favorite)prefs.saveFavorites(s);else prefs.savePinned(s);renderGames();}

    private void showAdd(){
        new Thread(()->{
            List<Game> all=apps();Set<String> selected=prefs.manualGames();List<Game> c=new ArrayList<>();
            for(Game g:all)if(!g.detected&&!selected.contains(g.pkg))c.add(g);
            Collections.sort(c,Comparator.comparing(x->x.label.toLowerCase(Locale.ROOT)));
            String[] labels=new String[c.size()];for(int n=0;n<c.size();n++)labels[n]=c.get(n).label+"\n"+c.get(n).pkg;
            runOnUiThread(()->new AlertDialog.Builder(this).setTitle("Adicionar aplicativo como jogo").setItems(labels,(d,w)->{
                Set<String>s=prefs.manualGames();s.add(c.get(w).pkg);prefs.saveManualGames(s);loadGames();
            }).setNegativeButton("Cancelar",null).show());
        }).start();
    }

    private void cycleSort(){sortMode=(sortMode+1)%3;String[]n={"A-Z","Mais jogados","Mais recentes"};message("Ordenação: "+n[sortMode],MUTED);renderGames();}

    private void optimize(Game g,boolean launch){
        List<String> report=new ArrayList<>();DeviceMonitor.Sample before=monitor.sample(this);
        AudioManager a=(AudioManager)getSystemService(AUDIO_SERVICE);
        try{
            if(!prefs.has("restore_volume"))prefs.putInt("restore_volume",a.getStreamVolume(AudioManager.STREAM_MUSIC));
            int max=a.getStreamMaxVolume(AudioManager.STREAM_MUSIC);a.setStreamVolume(AudioManager.STREAM_MUSIC,Math.round(max*prefs.profileVolume(g.pkg)/100f),0);
            report.add("✓ Volume: "+prefs.profileVolume(g.pkg)+"%");
        }catch(Exception e){report.add("⚠ Volume: "+e.getClass().getSimpleName());}

        if(Settings.System.canWrite(this)){
            try{
                if(!prefs.has("restore_brightness")){
                    prefs.putInt("restore_brightness",Settings.System.getInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS,128));
                    prefs.putInt("restore_brightness_mode",Settings.System.getInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS_MODE,Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC));
                }
                Settings.System.putInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS_MODE,Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
                Settings.System.putInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS,Math.max(8,Math.round(255f*prefs.profileBrightness(g.pkg)/100f)));
                report.add("✓ Brilho: "+prefs.profileBrightness(g.pkg)+"%");
            }catch(Exception e){report.add("⚠ Brilho: falhou");}
        }else report.add("⚠ Brilho: conceda Alterar configurações");

        NotificationManager nm=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
        if(prefs.profileDnd(g.pkg)){
            if(nm.isNotificationPolicyAccessGranted()){
                try{if(!prefs.has("restore_dnd"))prefs.putInt("restore_dnd",nm.getCurrentInterruptionFilter());nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY);report.add("✓ Não Perturbe: prioridade");}
                catch(Exception e){report.add("⚠ Não Perturbe: falhou");}
            }else report.add("⚠ Não Perturbe: acesso não concedido");
        }else report.add("• Não Perturbe: desativado no perfil");

        if(!Float.isNaN(before.batteryTemp)&&before.batteryTemp>=45f)report.add("⚠ Temperatura inicial alta: "+String.format(Locale.getDefault(),"%.1f°C",before.batteryTemp));
        report.add("• Tela atual: "+(before.refreshHz>0?String.format(Locale.getDefault(),"%.0f Hz",before.refreshHz):"indisponível"));
        report.add("• FPS: não é exposto genericamente pelo Android para outro app");
        report.add("• CPU/GPU: sem alteração, pois controle de outro app requer sistema/OEM/root");

        String text=TextUtils.join("\n",report);prefs.putString("last_boost_report",g.label+" • "+prefs.profileMode(g.pkg)+"\n"+text);
        message("BOOST aplicado com "+report.size()+" verificações",GREEN);
        Toast.makeText(this,"Perfil aplicado: "+prefs.profileMode(g.pkg),Toast.LENGTH_SHORT).show();
        if(launch)launch(g);
    }

    private void launch(Game g){
        Intent i=getPackageManager().getLaunchIntentForPackage(g.pkg);if(i==null){message("Não encontrei entrada para "+g.label,RED);return;}
        if(prefs.hasActiveSession())finishActiveSession("substituída por nova sessão");
        DeviceMonitor.Sample sample=monitor.sample(this);prefs.startSession(g.pkg,g.label,prefs.profileMode(g.pkg),sample);
        startFg(new Intent(this,SessionService.class));
        if(prefs.profileOverlay(g.pkg)){
            if(Settings.canDrawOverlays(this))startFg(new Intent(this,OverlayService.class));
            else message("Jogo iniciado; overlay aguardando permissão",AMBER);
        }
        leftForGame=false;
        try{startActivity(i);}catch(Exception e){prefs.clearActive();stopServices();message("Falha ao iniciar: "+e.getMessage(),RED);}
    }

    private void finishActiveSession(String reason){
        if(!prefs.hasActiveSession())return;
        SessionRecord r=prefs.finishSession(monitor.sample(this));stopServices();restore();refreshAnalytics();
        if(r!=null)message("Sessão salva: "+r.label+" • "+DeviceMonitor.duration(r.duration()),GREEN);else message("Sessão curta descartada",MUTED);
    }

    private void stopServices(){try{stopService(new Intent(this,SessionService.class));}catch(Exception ignored){}try{stopService(new Intent(this,OverlayService.class));}catch(Exception ignored){}}

    private void restore(){
        AudioManager a=(AudioManager)getSystemService(AUDIO_SERVICE);
        if(prefs.has("restore_volume"))try{a.setStreamVolume(AudioManager.STREAM_MUSIC,prefs.getInt("restore_volume",a.getStreamVolume(AudioManager.STREAM_MUSIC)),0);}catch(Exception ignored){}
        if(Settings.System.canWrite(this)&&prefs.has("restore_brightness"))try{
            Settings.System.putInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS_MODE,prefs.getInt("restore_brightness_mode",Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC));
            Settings.System.putInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS,prefs.getInt("restore_brightness",128));
        }catch(Exception ignored){}
        NotificationManager nm=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
        if(nm.isNotificationPolicyAccessGranted()&&prefs.has("restore_dnd"))try{nm.setInterruptionFilter(prefs.getInt("restore_dnd",NotificationManager.INTERRUPTION_FILTER_ALL));}catch(Exception ignored){}
        prefs.clearRestoreKeys();message("Configurações restauradas",GREEN);
    }

    private void refreshAnalytics(){
        if(history==null)return;
        List<SessionRecord>s=prefs.sessions();history.setText(prefs.historyText());graph.setSessions(s);ranking.setText(rankingText(s));
    }

    private String rankingText(List<SessionRecord>s){
        if(s.isEmpty())return"Sem dados suficientes para ranking.";
        Map<String,Long> totals=new HashMap<>();Map<String,String>labels=new HashMap<>();
        for(SessionRecord r:s){totals.put(r.packageName,totals.getOrDefault(r.packageName,0L)+r.duration());labels.put(r.packageName,r.label);}
        List<Map.Entry<String,Long>>e=new ArrayList<>(totals.entrySet());e.sort((a,b)->Long.compare(b.getValue(),a.getValue()));
        StringBuilder out=new StringBuilder("Mais jogados localmente\n");for(int i=0;i<Math.min(5,e.size());i++)out.append(i+1).append(". ").append(labels.get(e.get(i).getKey())).append(" • ").append(DeviceMonitor.duration(e.get(i).getValue())).append('\n');
        return out.toString().trim();
    }

    private long todayPlayed(String pkg){Calendar c=Calendar.getInstance();c.set(Calendar.HOUR_OF_DAY,0);c.set(Calendar.MINUTE,0);c.set(Calendar.SECOND,0);c.set(Calendar.MILLISECOND,0);long start=c.getTimeInMillis(),t=0;for(SessionRecord r:prefs.sessions())if(pkg.equals(r.packageName)&&r.startedAt>=start)t+=r.duration();return t;}
    private long lastPlayed(String pkg){for(SessionRecord r:prefs.sessions())if(pkg.equals(r.packageName))return r.endedAt;return 0;}

    private void manageHistory(){
        List<SessionRecord>s=prefs.sessions();if(s.isEmpty()){Toast.makeText(this,"Sem sessões",Toast.LENGTH_SHORT).show();return;}
        String[]items=new String[Math.min(50,s.size())];for(int i=0;i<items.length;i++){SessionRecord r=s.get(i);items[i]=r.label+" • "+DeviceMonitor.duration(r.duration())+" • "+DateFormat.getDateTimeInstance(DateFormat.SHORT,DateFormat.SHORT).format(new java.util.Date(r.startedAt));}
        new AlertDialog.Builder(this).setTitle("Toque para excluir uma sessão").setItems(items,(d,w)->new AlertDialog.Builder(this).setTitle("Excluir esta sessão?").setMessage(items[w]).setPositiveButton("Excluir",(a,b)->{prefs.deleteSession(w);refreshAnalytics();renderGames();}).setNegativeButton("Cancelar",null).show()).setNegativeButton("Fechar",null).show();
    }

    private void showCompatibility(){new AlertDialog.Builder(this).setTitle("Compatibilidade deste aparelho").setMessage(monitor.compatibility(this)).setPositiveButton("OK",null).show();}

    private String permissionSummary(){
        NotificationManager nm=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
        boolean notif=Build.VERSION.SDK_INT<33||checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED;
        return "Uso: "+mark(DeviceMonitor.hasUsageAccess(this))+"  •  DND: "+mark(nm.isNotificationPolicyAccessGranted())+"\n"+
                "Brilho: "+mark(Settings.System.canWrite(this))+"  •  Overlay: "+mark(Settings.canDrawOverlays(this))+"  •  Notificações: "+mark(notif);
    }
    private String mark(boolean b){return b?"✓":"—";}

    private String networkDetails(){return "Conexão: "+DeviceMonitor.network(this)+"\nIP local: "+DeviceMonitor.localIpv4()+"\nDNS: "+DeviceMonitor.dns(this)+"\nO teste abaixo mede 1.1.1.1:443, não o ping do jogo.";}
    private void runLatency(){networkInfo.setText("Testando 5 conexões...");new Thread(()->{String r=DeviceMonitor.latencyTest();runOnUiThread(()->networkInfo.setText(networkDetails()+"\n\n"+r));}).start();}

    private void requestProjection(String action){
        pendingCaptureAction=action;requestNotifications();
        MediaProjectionManager m=(MediaProjectionManager)getSystemService(MEDIA_PROJECTION_SERVICE);
        startActivityForResult(m.createScreenCaptureIntent(),RC_CAPTURE);
    }

    private void requestNotifications(){if(Build.VERSION.SDK_INT>=33&&checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},501);}

    @Override protected void onActivityResult(int req,int result,Intent data){
        super.onActivityResult(req,result,data);
        if(req==RC_CAPTURE&&result==RESULT_OK&&data!=null){
            Intent s=new Intent(this,CaptureService.class).setAction(pendingCaptureAction);
            s.putExtra(CaptureService.EXTRA_RESULT_CODE,result);s.putExtra(CaptureService.EXTRA_RESULT_DATA,data);startFg(s);
            message(CaptureService.ACTION_RECORD.equals(pendingCaptureAction)?"Gravação iniciada":"Captura solicitada",GREEN);return;
        }
        if(result!=RESULT_OK||data==null||data.getData()==null)return;
        Uri uri=data.getData();
        try{
            if(req==RC_EXPORT_CSV)writeUri(uri,prefs.exportSessionsCsv());
            else if(req==RC_EXPORT_JSON)writeUri(uri,prefs.exportSessionsJson());
            else if(req==RC_EXPORT_PROFILES)writeUri(uri,prefs.exportProfiles().toString(2));
            else if(req==RC_IMPORT_PROFILES){
                String raw=readUri(uri,1_000_000);int count=prefs.importProfiles(new JSONObject(raw));message(count+" perfil(is) importado(s)",GREEN);renderGames();
            }
        }catch(Exception e){message("Falha no arquivo: "+e.getMessage(),RED);}
    }

    private void createDocument(String type,String name,int rc){Intent i=new Intent(Intent.ACTION_CREATE_DOCUMENT);i.setType(type);i.putExtra(Intent.EXTRA_TITLE,name);i.addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(i,rc);}
    private void openProfileImport(){Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);i.setType("application/json");i.addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(i,RC_IMPORT_PROFILES);}
    private void writeUri(Uri uri,String data)throws Exception{try(OutputStream o=getContentResolver().openOutputStream(uri)){if(o==null)throw new IllegalStateException("Sem acesso ao arquivo");o.write(data.getBytes(StandardCharsets.UTF_8));}message("Arquivo exportado",GREEN);}
    private String readUri(Uri uri,int limit)throws Exception{try(InputStream in=getContentResolver().openInputStream(uri)){if(in==null)throw new IllegalStateException("Sem acesso ao arquivo");ByteArrayOutputStream out=new ByteArrayOutputStream();byte[]buf=new byte[8192];int n,total=0;while((n=in.read(buf))>0){total+=n;if(total>limit)throw new IllegalArgumentException("Arquivo grande demais");out.write(buf,0,n);}return out.toString(StandardCharsets.UTF_8.name());}}

    private void showBoostReport(){String r=prefs.getString("last_boost_report","Nenhum BOOST executado ainda.");new AlertDialog.Builder(this).setTitle("Último relatório BOOST").setMessage(r).setPositiveButton("OK",null).show();}

    private void pinShortcut(Game g){
        if(Build.VERSION.SDK_INT<26){Toast.makeText(this,"Atalho fixo requer Android 8+",Toast.LENGTH_SHORT).show();return;}
        ShortcutManager sm=getSystemService(ShortcutManager.class);if(sm==null||!sm.isRequestPinShortcutSupported()){Toast.makeText(this,"Launcher não aceita atalho fixo",Toast.LENGTH_SHORT).show();return;}
        Intent i=new Intent(this,MainActivity.class).setAction(Intent.ACTION_VIEW).putExtra("launch_pkg",g.pkg);
        ShortcutInfo s=new ShortcutInfo.Builder(this,"turbo_"+Math.abs(g.pkg.hashCode())).setShortLabel(g.label).setLongLabel("Iniciar "+g.label+" pelo Game Turbo").setIcon(Icon.createWithResource(this,R.drawable.ic_turbo)).setIntent(i).build();
        sm.requestPinShortcut(s,null);
    }

    private void launchShortcutWhenReady(){if(TextUtils.isEmpty(shortcutPackage)||loadedGames.isEmpty())return;String p=shortcutPackage;shortcutPackage=null;for(Game g:loadedGames)if(g.pkg.equals(p)){optimize(g,true);return;}message("Jogo do atalho não está mais disponível",RED);}

    private void recoverSessionIfNeeded(){
        if(!prefs.hasActiveSession())return;
        long elapsed=System.currentTimeMillis()-prefs.activeStart();
        new AlertDialog.Builder(this).setTitle("Sessão anterior encontrada")
                .setMessage("Há uma sessão pendente de "+DeviceMonitor.duration(elapsed)+". Isso pode acontecer se o Android encerrou o Game Turbo em segundo plano.")
                .setPositiveButton("Finalizar e restaurar",(d,w)->finishActiveSession("recuperada após interrupção"))
                .setNegativeButton("Manter ativa",null).show();
    }

    private void confirmClearHistory(){new AlertDialog.Builder(this).setTitle("Limpar histórico?").setMessage("Perfis e jogos serão mantidos.").setPositiveButton("Limpar",(d,w)->{prefs.clearHistory();refreshAnalytics();renderGames();}).setNegativeButton("Cancelar",null).show();}
    private void confirmClearAll(){new AlertDialog.Builder(this).setTitle("Apagar todos os dados locais?").setMessage("Isso remove histórico, favoritos, jogos manuais e perfis.").setPositiveButton("Apagar",(d,w)->{stopServices();prefs.clearAll();restore();loadGames();refreshAnalytics();}).setNegativeButton("Cancelar",null).show();}

    private String sessionStatus(){return prefs.hasActiveSession()?"Sessão ativa • "+prefs.activePackage()+" • "+DeviceMonitor.duration(System.currentTimeMillis()-prefs.activeStart()):"Nenhuma sessão ativa";}

    private void open(String action,boolean pkg){
        Intent i=new Intent(action);if(pkg)i.setData(Uri.parse("package:"+getPackageName()));
        try{startActivity(i);}catch(ActivityNotFoundException e){startActivity(new Intent(Settings.ACTION_SETTINGS));}
    }

    private void startFg(Intent i){if(Build.VERSION.SDK_INT>=26)startForegroundService(i);else startService(i);}
    private void message(String s,int color){if(status!=null){status.setText(s);status.setTextColor(color);}}

    private TextView section(String s){TextView t=text(s,12,MUTED,true);t.setPadding(0,dp(20),0,dp(8));return t;}
    private TextView text(String s,int sp,int color,boolean bold){TextView t=new TextView(this);t.setText(s);t.setTextSize(sp);t.setTextColor(color);if(bold)t.setTypeface(android.graphics.Typeface.DEFAULT,android.graphics.Typeface.BOLD);return t;}
    private LinearLayout verticalCard(){LinearLayout l=new LinearLayout(this);l.setOrientation(LinearLayout.VERTICAL);l.setPadding(dp(14),dp(12),dp(14),dp(12));l.setBackground(round(CARD,18));return l;}
    private View card(View child){LinearLayout l=verticalCard();l.addView(child);return l;}
    private LinearLayout row(){LinearLayout l=new LinearLayout(this);l.setOrientation(LinearLayout.HORIZONTAL);l.setGravity(Gravity.CENTER_VERTICAL);return l;}
    private View gap(){View v=new View(this);v.setLayoutParams(new LinearLayout.LayoutParams(dp(7),1));return v;}
    private View spacer(int h){View v=new View(this);v.setLayoutParams(new LinearLayout.LayoutParams(1,dp(h)));return v;}
    private LinearLayout.LayoutParams weight(){return new LinearLayout.LayoutParams(0,dp(44),1f);}
    private Button button(String s,int color,View.OnClickListener x){Button b=new Button(this);b.setText(s);b.setTextColor(TEXT);b.setTextSize(11);b.setAllCaps(false);b.setPadding(dp(4),0,dp(4),0);b.setBackground(round(color,14));b.setOnClickListener(x);return b;}
    private GradientDrawable round(int color,int r){GradientDrawable g=new GradientDrawable();g.setColor(color);g.setCornerRadius(dp(r));return g;}
    private int dp(int v){return Math.round(v*getResources().getDisplayMetrics().density);}
}
