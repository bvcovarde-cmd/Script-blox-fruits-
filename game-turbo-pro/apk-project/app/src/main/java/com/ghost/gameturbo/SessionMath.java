package com.ghost.gameturbo;

final class SessionMath {
    private SessionMath() {}
    static long duration(long start,long end){return Math.max(0L,end-start);}
    static int clampPercent(int value){return Math.max(0,Math.min(100,value));}
}
