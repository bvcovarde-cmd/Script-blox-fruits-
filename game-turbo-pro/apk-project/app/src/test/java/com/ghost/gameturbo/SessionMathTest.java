package com.ghost.gameturbo;

import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class SessionMathTest {
    @Test public void durationNeverNegative(){
        assertEquals(0L,SessionMath.duration(2000L,1000L));
        assertEquals(1500L,SessionMath.duration(1000L,2500L));
    }
    @Test public void percentIsClamped(){
        assertEquals(0,SessionMath.clampPercent(-5));
        assertEquals(42,SessionMath.clampPercent(42));
        assertEquals(100,SessionMath.clampPercent(500));
    }
}
