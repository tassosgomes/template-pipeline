package com.exemplo;

import java.io.IOException;

/**
 * VULNERABILIDADE PLANTADA — NÃO CORRIJA.
 *
 * <p>Passar entrada do usuário direto para {@code Runtime.exec} é command injection.
 * O Semgrep reporta isto pelos rulesets p/security-audit e p/owasp-top-ten.
 *
 * <p>É este achado que o self-test da plataforma usa para provar que o SAST está realmente
 * analisando o código e que o gate de severidade funciona. Remover isto faz o job
 * {@code sast-detecta-vulnerabilidade} do _selftest.yml falhar.
 */
public final class Insecure {

    private Insecure() {
    }

    /** Executa um comando vindo do usuário. Deliberadamente inseguro. */
    public static Process listarArquivos(String diretorioDoUsuario) throws IOException {
        return Runtime.getRuntime().exec("ls " + diretorioDoUsuario);
    }
}
