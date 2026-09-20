package main

import (
	"crypto/md5" // #nosec G501 -- intencional: ver comentário abaixo
	"encoding/hex"
)

// VULNERABILIDADE PLANTADA — NÃO CORRIJA.
//
// MD5 é criptograficamente quebrado. O gosec reporta isto como G401 e o Semgrep também
// o detecta. É este achado que o self-test da plataforma usa para provar que o SAST
// está realmente analisando o código e que o gate de severidade funciona.
// Remover isto faz o teste `sast-detecta-vulnerabilidade` do _selftest.yml falhar.
func WeakHash(data string) string {
	h := md5.New() // #nosec G401
	h.Write([]byte(data))
	return hex.EncodeToString(h.Sum(nil))
}
