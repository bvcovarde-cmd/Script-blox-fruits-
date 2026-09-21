package com.ghost.gameturbo;

import android.app.AlertDialog;
import android.content.Context;
import android.graphics.Color;
import android.widget.ArrayAdapter;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.TextView;

final class ProfileDialog {
    interface Saved { void done(); }

    static void show(Context c, TurboPrefs prefs, String pkg, String label, Saved saved) {
        LinearLayout box=new LinearLayout(c);box.setOrientation(LinearLayout.VERTICAL);box.setPadding(dp(c,20),dp(c,8),dp(c,20),0);

        box.addView(label(c,"Modo"));
        Spinner mode=new Spinner(c);
        String[] modes={"Desempenho","Equilibrado","Economia","Personalizado"};
        ArrayAdapter<String> adapter=new ArrayAdapter<>(c,android.R.layout.simple_spinner_dropdown_item,modes);
        mode.setAdapter(adapter);
        String current=prefs.profileMode(pkg);
        for(int i=0;i<modes.length;i++)if(modes[i].equals(current))mode.setSelection(i);
        box.addView(mode);

        CheckBox dnd=new CheckBox(c);dnd.setText("Reduzir interrupções (Não Perturbe)");dnd.setTextColor(Color.WHITE);dnd.setChecked(prefs.profileDnd(pkg));box.addView(dnd);
        CheckBox overlay=new CheckBox(c);overlay.setText("Overlay durante a sessão");overlay.setTextColor(Color.WHITE);overlay.setChecked(prefs.profileOverlay(pkg));box.addView(overlay);

        TextView vl=label(c,"Volume de mídia");box.addView(vl);
        SeekBar vol=new SeekBar(c);vol.setMax(100);vol.setProgress(prefs.profileVolume(pkg));box.addView(vol);

        TextView bl=label(c,"Brilho");box.addView(bl);
        SeekBar bri=new SeekBar(c);bri.setMax(100);bri.setProgress(prefs.profileBrightness(pkg));box.addView(bri);

        mode.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener(){
            boolean first=true;
            public void onItemSelected(android.widget.AdapterView<?> parent,android.view.View view,int pos,long id){
                if(first){first=false;return;}
                String m=modes[pos];
                if("Desempenho".equals(m)){dnd.setChecked(true);overlay.setChecked(true);vol.setProgress(90);bri.setProgress(80);}
                else if("Equilibrado".equals(m)){dnd.setChecked(true);overlay.setChecked(false);vol.setProgress(80);bri.setProgress(65);}
                else if("Economia".equals(m)){dnd.setChecked(false);overlay.setChecked(false);vol.setProgress(65);bri.setProgress(45);}
            }
            public void onNothingSelected(android.widget.AdapterView<?> parent){}
        });

        new AlertDialog.Builder(c).setTitle("Perfil • "+label).setView(box)
                .setPositiveButton("Salvar",(d,w)->{
                    prefs.saveProfile(pkg,String.valueOf(mode.getSelectedItem()),dnd.isChecked(),overlay.isChecked(),vol.getProgress(),bri.getProgress());
                    saved.done();
                })
                .setNeutralButton("Padrão",(d,w)->{prefs.applyPreset(pkg,"Equilibrado");saved.done();})
                .setNegativeButton("Cancelar",null).show();
    }
    private static TextView label(Context c,String s){TextView t=new TextView(c);t.setText(s);t.setTextColor(Color.LTGRAY);t.setPadding(0,dp(c,8),0,0);return t;}
    private static int dp(Context c,int v){return Math.round(v*c.getResources().getDisplayMetrics().density);}
}
