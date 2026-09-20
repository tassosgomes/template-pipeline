package com.exemplo;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class CalcTest {

    @Test
    void somaDoisInteiros() {
        assertEquals(5, Calc.soma(2, 3));
    }
}
