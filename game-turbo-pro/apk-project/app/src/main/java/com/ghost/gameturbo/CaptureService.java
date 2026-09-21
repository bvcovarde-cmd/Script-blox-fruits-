package com.ghost.gameturbo;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.ContentValues;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.PixelFormat;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.media.Image;
import android.media.ImageReader;
import android.media.MediaRecorder;
import android.media.projection.MediaProjection;
import android.media.projection.MediaProjectionManager;
import android.net.Uri;
import android.os.Build;
import android.os.IBinder;
import android.os.ParcelFileDescriptor;
import android.provider.MediaStore;
import android.util.DisplayMetrics;
import android.view.Surface;

import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class CaptureService extends Service {
    public static final String ACTION_CAPTURE="CAPTURE";
    public static final String ACTION_RECORD="RECORD";
    public static final String ACTION_STOP="STOP";
    public static final String EXTRA_RESULT_CODE="result_code";
    public static final String EXTRA_RESULT_DATA="result_data";

    private MediaProjection projection;
    private VirtualDisplay virtualDisplay;
    private ImageReader imageReader;
    private MediaRecorder recorder;
    private ParcelFileDescriptor videoPfd;
    private Uri videoUri;
    private boolean recording, closing;

    @Override public void onCreate(){super.onCreate();channel();}

    @Override public int onStartCommand(Intent i,int flags,int id){
        if(i==null)return START_NOT_STICKY;
        if(ACTION_STOP.equals(i.getAction())){finishRecording();return START_NOT_STICKY;}
        startForeground(3001,notification("Preparando captura",false));
        int code=i.getIntExtra(EXTRA_RESULT_CODE,0);
        Intent data;
        if(Build.VERSION.SDK_INT>=33)data=i.getParcelableExtra(EXTRA_RESULT_DATA,Intent.class);else data=i.getParcelableExtra(EXTRA_RESULT_DATA);
        if(data==null||code==0){stopSelf();return START_NOT_STICKY;}
        MediaProjectionManager m=(MediaProjectionManager)getSystemService(MEDIA_PROJECTION_SERVICE);
        projection=m.getMediaProjection(code,data);
        if(projection==null){stopSelf();return START_NOT_STICKY;}
        projection.registerCallback(new MediaProjection.Callback(){
            @Override public void onStop(){if(closing)return;if(recording)finishRecording();else cleanup();}
        },new android.os.Handler(getMainLooper()));
        if(ACTION_RECORD.equals(i.getAction()))startRecording();else takeScreenshot();
        return START_NOT_STICKY;
    }

    private void takeScreenshot(){
        try{
            DisplayMetrics dm=getResources().getDisplayMetrics();int w=dm.widthPixels,h=dm.heightPixels;
            imageReader=ImageReader.newInstance(w,h,PixelFormat.RGBA_8888,2);
            virtualDisplay=projection.createVirtualDisplay("GameTurboShot",w,h,dm.densityDpi,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,imageReader.getSurface(),null,null);
            imageReader.setOnImageAvailableListener(reader->{
                Image img=null;
                try{
                    img=reader.acquireLatestImage();if(img==null)return;
                    Image.Plane p=img.getPlanes()[0];ByteBuffer buffer=p.getBuffer();
                    int pixelStride=p.getPixelStride(),rowStride=p.getRowStride(),padding=rowStride-pixelStride*w;
                    Bitmap wide=Bitmap.createBitmap(w+padding/pixelStride,h,Bitmap.Config.ARGB_8888);wide.copyPixelsFromBuffer(buffer);
                    Bitmap crop=Bitmap.createBitmap(wide,0,0,w,h);saveImage(crop);wide.recycle();crop.recycle();
                }catch(Exception ignored){}finally{if(img!=null)img.close();cleanup();}
            },new android.os.Handler(getMainLooper()));
        }catch(Exception e){cleanup();}
    }

    private void saveImage(Bitmap b)throws Exception{
        String name="GameTurbo_"+stamp()+".png";ContentValues v=new ContentValues();
        v.put(MediaStore.Images.Media.DISPLAY_NAME,name);v.put(MediaStore.Images.Media.MIME_TYPE,"image/png");
        v.put(MediaStore.Images.Media.RELATIVE_PATH,"Pictures/GameTurboPro");v.put(MediaStore.Images.Media.IS_PENDING,1);
        Uri uri=getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,v);if(uri==null)return;
        boolean ok=false;try(OutputStream o=getContentResolver().openOutputStream(uri)){ok=o!=null&&b.compress(Bitmap.CompressFormat.PNG,100,o);}
        if(ok){v.clear();v.put(MediaStore.Images.Media.IS_PENDING,0);getContentResolver().update(uri,v,null,null);}else getContentResolver().delete(uri,null,null);
    }

    private void startRecording(){
        try{
            DisplayMetrics dm=getResources().getDisplayMetrics();int w=dm.widthPixels-(dm.widthPixels%2),h=dm.heightPixels-(dm.heightPixels%2);
            ContentValues v=new ContentValues();v.put(MediaStore.Video.Media.DISPLAY_NAME,"GameTurbo_"+stamp()+".mp4");v.put(MediaStore.Video.Media.MIME_TYPE,"video/mp4");
            v.put(MediaStore.Video.Media.RELATIVE_PATH,"Movies/GameTurboPro");v.put(MediaStore.Video.Media.IS_PENDING,1);
            videoUri=getContentResolver().insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI,v);if(videoUri==null)throw new IllegalStateException("Sem destino");
            videoPfd=getContentResolver().openFileDescriptor(videoUri,"w");if(videoPfd==null)throw new IllegalStateException("Sem arquivo");
            recorder=new MediaRecorder();recorder.setVideoSource(MediaRecorder.VideoSource.SURFACE);recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            recorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264);recorder.setVideoEncodingBitRate(8_000_000);recorder.setVideoFrameRate(30);recorder.setVideoSize(w,h);
            recorder.setOutputFile(videoPfd.getFileDescriptor());recorder.prepare();Surface s=recorder.getSurface();
            virtualDisplay=projection.createVirtualDisplay("GameTurboRecord",w,h,dm.densityDpi,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,s,null,null);
            recorder.start();recording=true;
            ((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(3001,notification("Gravando tela • toque em Parar",true));
        }catch(Exception e){abortVideo();}
    }

    private android.app.Notification notification(String text,boolean stop){
        Intent open=new Intent(this,MainActivity.class);PendingIntent content=PendingIntent.getActivity(this,30,open,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        android.app.Notification.Builder b=new android.app.Notification.Builder(this,"turbo_capture").setSmallIcon(R.drawable.ic_turbo)
                .setContentTitle("Game Turbo Pro").setContentText(text).setContentIntent(content).setOngoing(true);
        if(stop){Intent si=new Intent(this,CaptureService.class).setAction(ACTION_STOP);PendingIntent spi=PendingIntent.getService(this,31,si,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);b.addAction(new android.app.Notification.Action.Builder(null,"Parar",spi).build());}
        return b.build();
    }

    private void finishRecording(){
        boolean ok=false;
        if(recording&&recorder!=null){try{recorder.stop();ok=true;}catch(Exception ignored){}}
        recording=false;
        try{if(recorder!=null)recorder.reset();}catch(Exception ignored){}
        try{if(recorder!=null)recorder.release();}catch(Exception ignored){}recorder=null;
        if(virtualDisplay!=null){try{virtualDisplay.release();}catch(Exception ignored){}virtualDisplay=null;}
        closing=true;if(projection!=null){try{projection.stop();}catch(Exception ignored){}projection=null;}
        try{if(videoPfd!=null)videoPfd.close();}catch(Exception ignored){}videoPfd=null;
        if(videoUri!=null){
            if(ok){ContentValues v=new ContentValues();v.put(MediaStore.Video.Media.IS_PENDING,0);try{getContentResolver().update(videoUri,v,null,null);}catch(Exception ignored){}}
            else try{getContentResolver().delete(videoUri,null,null);}catch(Exception ignored){}
        }
        videoUri=null;stopSelf();
    }

    private void abortVideo(){recording=false;try{if(recorder!=null)recorder.release();}catch(Exception ignored){}recorder=null;if(videoUri!=null)try{getContentResolver().delete(videoUri,null,null);}catch(Exception ignored){}cleanup();}
    private void cleanup(){if(closing)return;closing=true;if(virtualDisplay!=null)try{virtualDisplay.release();}catch(Exception ignored){}virtualDisplay=null;if(imageReader!=null)try{imageReader.close();}catch(Exception ignored){}imageReader=null;if(projection!=null)try{projection.stop();}catch(Exception ignored){}projection=null;stopSelf();}
    private void channel(){if(Build.VERSION.SDK_INT>=26){NotificationChannel c=new NotificationChannel("turbo_capture","Capturas Game Turbo",NotificationManager.IMPORTANCE_LOW);((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(c);}}
    private String stamp(){return new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date());}
    @Override public IBinder onBind(Intent i){return null;}
}
