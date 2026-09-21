package com.ghost.gameturbo;

import android.app.AlertDialog;
import android.content.Context;
import android.graphics.Color;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.TextView;

final class ProfileDialog {
    interface Saved { void done(); }
    static void show(Context c, TurboPrefs prefs, String pkg, String label, Saved saved) {
        LinearLayout box=new LinearLayout(c);box.setOrientation(LinearLayout.VERTICAL);box.setPadding(dp(c,20),dp(c,8),dp(c,20),0);
        CheckBox dnd=new CheckBox(c);dnd.setText("Reduzir interrupções (Não Perturbe)");dnd.setTextColor(Color.WHITE);dnd.setChecked(prefs.profileDnd(pkg));box.addView(dnd);
        TextView vl=label(c,"Volume de mídia");box.addView(vl);SeekBar vol=new SeekBar(c);vol.setMax(100);vol.setProgress(prefs.profileVolume(pkg));box.addView(vol);
        TextView bl=label(c,"Brilho");box.addView(bl);SeekBar bri=new SeekBar(c);bri.setMax(100);bri.setProgress(prefs.profileBrightness(pkg));box.addView(bri);
        new AlertDialog.Builder(c).setTitle("Perfil • "+label).setView(box).setPositiveButton("Salvar",(d,w)->{prefs.saveProfile(pkg,dnd.isChecked(),vol.getProgress(),bri.getProgress());saved.done();}).setNegativeButton("Cancelar",null).show();
    }
    private static TextView label(Context c,String s){TextView t=new TextView(c);t.setText(s);t.setTextColor(Color.LTGRAY);t.setPadding(0,dp(c,8),0,0);return t;}
    private static int dp(Context c,int v){return Math.round(v*c.getResources().getDisplayMetrics().density);}
}
