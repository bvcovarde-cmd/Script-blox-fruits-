package com.ghost.gameturbo;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.view.View;

import java.util.Calendar;
import java.util.List;

final class SimpleGraphView extends View {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final long[] days=new long[7];

    SimpleGraphView(Context c){super(c);setMinimumHeight(dp(150));}

    void setSessions(List<SessionRecord> list){
        for(int i=0;i<7;i++)days[i]=0;
        Calendar now=Calendar.getInstance();
        zero(now);
        long today=now.getTimeInMillis();
        for(SessionRecord r:list){
            Calendar c=Calendar.getInstance();c.setTimeInMillis(r.startedAt);zero(c);
            long delta=(today-c.getTimeInMillis())/86_400_000L;
            if(delta>=0&&delta<7)days[6-(int)delta]+=r.duration();
        }
        invalidate();
    }

    @Override protected void onDraw(Canvas c){
        super.onDraw(c);float w=getWidth(),h=getHeight();if(w<=0||h<=0)return;
        long max=1;for(long v:days)max=Math.max(max,v);
        float gap=dp(8),bar=(w-gap*8)/7f,base=h-dp(28);
        paint.setTextSize(dp(10));paint.setTextAlign(Paint.Align.CENTER);
        String[] labels={"D-6","D-5","D-4","D-3","D-2","Ontem","Hoje"};
        for(int i=0;i<7;i++){
            float left=gap+(bar+gap)*i;float bh=(base-dp(10))*(days[i]/(float)max);
            paint.setColor(Color.rgb(139,92,246));c.drawRoundRect(left,base-bh,left+bar,base,dp(5),dp(5),paint);
            paint.setColor(Color.LTGRAY);c.drawText(labels[i],left+bar/2,h-dp(8),paint);
        }
    }
    private static void zero(Calendar c){c.set(Calendar.HOUR_OF_DAY,0);c.set(Calendar.MINUTE,0);c.set(Calendar.SECOND,0);c.set(Calendar.MILLISECOND,0);}
    private int dp(int v){return Math.round(v*getResources().getDisplayMetrics().density);}
}
