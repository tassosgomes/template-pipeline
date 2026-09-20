# Conta os resultados de um SARIF por severidade.
#
# GitHub code scanning usa `properties["security-severity"]` (escala CVSS) como fonte
# primária de severidade; quando a ferramenta não a emite, caímos para `result.level`.
# A faixa CVSS -> bucket segue a convenção do próprio code scanning.

def bucket_from_cvss($n):
  if   $n >= 9 then "critical"
  elif $n >= 7 then "high"
  elif $n >= 4 then "medium"
  else              "low"
  end;

def bucket_from_level($l):
  if   $l == "error"   then "high"
  elif $l == "warning" then "medium"
  else                      "low"
  end;

[ (.runs // [])[]
  | ( [ (.tool.driver.rules // [])[]
      , ((.tool.extensions // []) | map(.rules // []) | add // [])[]
      ]
      | map({ key: (.id // ""), value: (.properties["security-severity"] // null) })
      | from_entries
    ) as $rules
  | (.results // [])[]
  | { level: (.level // "warning")
    , ss:    ( .properties["security-severity"] // $rules[(.ruleId // "")] // null )
    }
]
| map(
    (.ss | if . == null then null else (tonumber? // null) end) as $n
    | if $n != null then bucket_from_cvss($n) else bucket_from_level(.level) end
  )
| { critical: (map(select(. == "critical")) | length)
  , high:     (map(select(. == "high"))     | length)
  , medium:   (map(select(. == "medium"))   | length)
  , low:      (map(select(. == "low"))      | length)
  , total:    length
  }
