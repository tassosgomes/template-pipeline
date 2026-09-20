// Package main é o fixture Go da plataforma: um projeto mínimo com teste real,
// cobertura real e uma vulnerabilidade plantada de propósito (ver insecure.go).
package main

import "fmt"

// Sum devolve a soma de dois inteiros.
func Sum(a, b int) int {
	return a + b
}

func main() {
	fmt.Println(Sum(2, 3))
}
