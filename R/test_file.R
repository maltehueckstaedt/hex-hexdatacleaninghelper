library(ellmer)

text <- "Praktikum, 1 SWS, Sprache Deutsch, Pflicht für MLS-B1, Zeit und Ort: Mi 13:00 - 14:00,H 4"

template <- "
Extrahiere aus dem folgenden Text – nur falls vorhanden – vier Variablen:
- ETCs (Text)
- Semesterwochenstunden (Text)
- Sprache (Text)
- Art des Kurses (Text)

Gib das Ergebnis als JSON mit den Schlüsseln etcs, sws, sprache und kursart aus.

Text: {text}
"

chat <- chat_openai(
  model = "gpt-4o",
  system_prompt = glue(template)
)

chat$chat("")
