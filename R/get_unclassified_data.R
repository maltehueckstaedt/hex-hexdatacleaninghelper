#' Filtert unklassifizierte Kursdaten aus der db_data_universitaet_>uni_name<.rds
#
#' Diese Funktion vergleicht aktuelle Scraping-Daten mit db_data_universitaet_>uni_name<.rds und gibt alle Zeilen aus den aktuellen Scraping-Daten zurück, 
#' die noch keiner der definierten Kategorien zugeordnet wurden. Die Identifikation erfolgt über 1 bis 3 Schlüsselvariablen.
#'
#' @param raw_data Ein \code{data.frame} mit den Rohdaten, die klassifiziert werden sollen.
#' @param db_data_path Pfad zu einer RDS-Datei mit den bereits klassifizierten Daten.
#' @param key_vars Ein Vektor mit 1 bis 3 Spaltennamen, die als Schlüssel für den Abgleich dienen (Standard: \code{c("titel", "nummer")}).
#'
#' @return Ein \code{data.frame} mit den Zeilen aus \code{raw_data}, die noch nicht klassifiziert wurden. Enthält die Schlüsselvariablen, \code{kursbeschreibung} und \code{lernziele}.
#'
#' @details
#' Die Funktion prüft, ob für jede Zeile in \code{raw_data} keine Klassifizierung in den Spalten 
#' \code{data_analytics_ki}, \code{softwareentwicklung}, \code{nutzerzentriertes_design}, 
#' \code{it_architektur}, \code{hardware_robotikentwicklung} und \code{quantencomputing} vorliegt.
#'
#' @examples
#' \dontrun{
#'   unclassified <- get_unclassified_data(
#'     raw_data = my_raw_data,
#'     db_data_path = "path/to/classified_data.rds",
#'     key_vars = c("titel", "nummer")
#'   )
#' }
#'
#' @export
get_unclassified_data <- function(raw_data, db_data_path, key_vars = c("titel", "nummer")) {
  # Sicherstellen, dass 1-3 Key-Variablen angegeben sind
  if (length(key_vars) < 1 || length(key_vars) > 3) {
    stop("Es müssen mindestens 1 und höchstens 3 Key-Variablen angegeben werden.")
  }
  
  # Klassifizierte Daten laden und nur relevante Spalten nehmen
  classified_data <- readRDS(db_data_path) %>%
    dplyr::select(
      dplyr::all_of(key_vars),
      data_analytics_ki,
      softwareentwicklung,
      nutzerzentriertes_design,
      it_architektur,
      hardware_robotikentwicklung,
      quantencomputing
    ) %>%
    dplyr::distinct(dplyr::across(dplyr::all_of(key_vars)), .keep_all = TRUE)
  
  # Join mit den Rohdaten über die Key-Variablen
  raw_data_join <- raw_data %>%
    dplyr::left_join(classified_data, by = key_vars)
  
  # Nur nicht klassifizierte Zeilen filtern
  raw_data_to_classify <- raw_data_join %>%
    dplyr::filter(
      is.na(data_analytics_ki) &
      is.na(softwareentwicklung) &
      is.na(nutzerzentriertes_design) &
      is.na(it_architektur) &
      is.na(hardware_robotikentwicklung) &
      is.na(quantencomputing)
    ) %>%
    dplyr::select(dplyr::all_of(key_vars), kursbeschreibung, lernziele)
  
  return(raw_data_to_classify)
}