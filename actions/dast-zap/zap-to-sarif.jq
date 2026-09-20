# Converte o relatório JSON do OWASP ZAP em SARIF 2.1.0.
#
# O ZAP não emite SARIF nativamente. Convertemos para que o DAST atravesse exatamente o
# mesmo caminho de publicação e de gate que o SAST (actions/upload-findings).
#
# riskcode do ZAP: 0=Informational, 1=Low, 2=Medium, 3=High.
# Traduzimos para a escala CVSS que o code scanning usa em `security-severity`.

def sev($risk):
  if   $risk == "3" then { level: "error",   score: "8.0" }
  elif $risk == "2" then { level: "warning", score: "5.0" }
  elif $risk == "1" then { level: "note",    score: "2.0" }
  else                   { level: "note",    score: "0.5" }
  end;

def strip_html: gsub("<[^>]*>"; "") | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ");

[ (.site // [])[] | (.alerts // [])[] ] as $alerts

| {
    version: "2.1.0",
    "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
    runs: [
      {
        tool: {
          driver: {
            name: "OWASP ZAP",
            informationUri: "https://www.zaproxy.org/",
            rules: (
              $alerts
              | group_by(.pluginid // "0")
              | map(
                  .[0] as $a
                  | sev($a.riskcode // "0") as $s
                  | {
                      id: ($a.pluginid // "0"),
                      name: ($a.alert // $a.name // "ZAP alert"),
                      shortDescription: { text: ($a.alert // $a.name // "ZAP alert") },
                      fullDescription:  { text: (($a.desc // "") | strip_html) },
                      help: {
                        text: ((($a.solution // "") | strip_html)
                               + (if ($a.cweid // "") != "" then "\nCWE-" + $a.cweid else "" end))
                      },
                      properties: {
                        "security-severity": $s.score,
                        tags: (["dast", "zap"]
                               + (if ($a.cweid // "") != "" then ["external/cwe/cwe-" + $a.cweid] else [] end))
                      }
                    }
                )
            )
          }
        },
        results: (
          $alerts
          | map(
              . as $a
              | sev($a.riskcode // "0") as $s
              | (if (($a.instances // []) | length) > 0 then ($a.instances // []) else [{ uri: "" }] end)
                | map({
                    ruleId: ($a.pluginid // "0"),
                    level: $s.level,
                    message: {
                      text: (($a.alert // $a.name // "ZAP alert")
                             + (if (.method // "") != "" then " [" + .method + "]" else "" end)
                             + (if (.param // "") != "" then " parâmetro: " + .param else "" end))
                    },
                    locations: [
                      { physicalLocation: {
                          artifactLocation: { uri: (.uri // "urn:zap:unknown") },
                          region: { startLine: 1 }
                      } }
                    ]
                  })
            )
          | add // []
        )
      }
    ]
  }
