library(ellmer)
library(glue)
library(jsonlite)
library(dplyr)
library(tidyr)

df <- readRDS("C:/Users/mhu/Downloads/data_universitaet_zu_luebeck.rds")
df <- df %>% sample_n(10) |> select(titel, details)
extract_course_info <- function(df, text_col = "details", model = "gpt-4o") {
  library(ellmer)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(progressr)
  library(glue)

  supported_models <- c("gpt-4o", "gpt-4-1106-preview", "gpt-3.5-turbo-1106")

  if (!model %in% supported_models) {
    stop(glue("❌ Modell '{model}' unterstützt kein structured output (json_schema). Bitte verwende z. B. gpt-4o."))
  }

  chat <- chat_openai(model = model)

  type_course <- type_object(
    "Extrahiere nur die folgenden Variablen, wenn sie explizit im Text genannt werden:",
    etcs = type_string("Anzahl der ECTS-Punkte", required = FALSE),
    sws = type_string("Semesterwochenstunden", required = FALSE),
    sprache = type_string("Unterrichtssprache", required = FALSE),
    kursart = type_string("Art des Kurses, z. B. Vorlesung, Seminar", required = FALSE)
  )

  safe_extract <- function(x) {
    tryCatch({
      Sys.sleep(1)  # TPM-Steuerung
      chat$extract_data(x, type = type_course)
    }, error = function(e) {
      if (grepl("Rate limit", e$message)) {
        message("⏳ Rate Limit erreicht – warte 5 Sekunden...")
        Sys.sleep(5)
        chat$extract_data(x, type = type_course)
      } else {
        warning("⚠️ Fehler bei der Extraktion: ", e$message)
        return(list(etcs = NA, sws = NA, sprache = NA, kursart = NA))
      }
    })
  }

  handlers(global = TRUE)
  message(glue("🔍 Starte Extraktion mit Modell: {model}..."))

  with_progress({
    p <- progressor(steps = nrow(df))
    df_result <- df %>%
      mutate(info = map(.data[[text_col]], function(x) {
        result <- safe_extract(x)
        p(message = substr(x, 1, 60))
        result
      })) %>%
      unnest_wider(info)
  })

  message("✅ Fertig!")
  return(df_result)
}
df_extracted <- extract_course_info(df, model = "gpt-4o")

View(df_extracted)




estimate_cost_from_token_usage <- function(input_tokens, output_tokens, model = "gpt-4o") {
  # Preise pro 1.000 Tokens in USD
  prices <- list(
    "gpt-4o" = list(input = 0.0025, output = 0.01),
    "gpt-4o-mini" = list(input = 0.00015, output = 0.0006),
    "gpt-3.5-turbo" = list(input = 0.0005, output = 0.0015)
  )
  
  if (!model %in% names(prices)) {
    stop("❌ Modellpreis nicht definiert.")
  }
  
  p_in <- prices[[model]]$input
  p_out <- prices[[model]]$output
  
  cost_input <- input_tokens * p_in / 1000
  cost_output <- output_tokens * p_out / 1000
  total_cost <- cost_input + cost_output
  
  message(glue::glue(
    "📊 Tokenverbrauch:\n",
    "📥 Input: {input_tokens} Tokens × ${p_in}/1k = ${round(cost_input, 4)}\n",
    "📤 Output: {output_tokens} Tokens × ${p_out}/1k = ${round(cost_output, 4)}\n",
    "💵 Geschätzte Gesamtkosten: ${round(total_cost, 4)} USD"
  ))
  
  return(total_cost)
}


# Beispiel: Tokenverbrauch anzeigen
usage <- token_usage()
input_tokens <- usage$input
output_tokens <- usage$output

# Kosten berechnen
estimate_cost_from_token_usage(input_tokens, output_tokens, model = "gpt-4o")