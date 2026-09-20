"""VULNERABILIDADE PLANTADA — NÃO CORRIJA.

`eval` sobre entrada arbitrária é execução remota de código. O bandit reporta como B307
e o Semgrep também o detecta.

É este achado que o self-test da plataforma usa para provar que o SAST está realmente
analisando o código e que o gate de severidade funciona. Remover isto faz o teste
`sast-detecta-vulnerabilidade` do _selftest.yml falhar.
"""


def render_template(expressao: str) -> object:
    """Avalia uma expressão vinda do usuário. Deliberadamente inseguro."""
    return eval(expressao)  # noqa: S307  # nosec B307
