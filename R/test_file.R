# Beispielaufruf mit 3 Key-Variablen
raw_data_bremen_to_classify_alt <- get_unclassified_data(
  raw_data_bremen,
  "C:/SV/HEX/Scraping/data/single_universities/Universitaet_Bremen/db_data_universitaet_bremen.rds",
  key_vars = c("titel", "nummer")
)

getwd()
