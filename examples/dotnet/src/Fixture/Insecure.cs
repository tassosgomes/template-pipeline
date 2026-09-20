namespace Fixture;

/// <summary>
/// VULNERABILIDADE PLANTADA — NÃO CORRIJA.
///
/// Concatenar entrada do usuário dentro de uma query SQL é SQL injection.
/// O Semgrep reporta isto pelos rulesets p/security-audit e p/owasp-top-ten.
///
/// É este achado que o self-test da plataforma usa para provar que o SAST está realmente
/// analisando o código e que o gate de severidade funciona. Remover isto faz o job
/// sast-detecta-vulnerabilidade do _selftest.yml falhar.
/// </summary>
public static class Insecure
{
    /// <summary>Monta uma query com entrada do usuário. Deliberadamente inseguro.</summary>
    public static string BuscarUsuario(string nomeDoUsuario)
    {
        return "SELECT * FROM usuarios WHERE nome = '" + nomeDoUsuario + "'";
    }
}
