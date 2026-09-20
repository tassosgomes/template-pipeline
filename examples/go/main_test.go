package main

import "testing"

func TestSum(t *testing.T) {
	if got := Sum(2, 3); got != 5 {
		t.Errorf("Sum(2, 3) = %d; esperado 5", got)
	}
}

func TestWeakHash(t *testing.T) {
	if got := WeakHash("abc"); got == "" {
		t.Error("WeakHash devolveu string vazia")
	}
}
