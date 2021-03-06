
#' Show algorithm help
#'
#' @inheritParams qgis_run_algorithm
#'
#' @export
#'
#' @examples
#' if (has_qgis()) qgis_show_help("native:filedownloader")
#' if (has_qgis()) qgis_description("native:filedownloader")
#' if (has_qgis()) qgis_arguments("native:filedownloader")
#'
qgis_show_help <- function(algorithm) {
  cat(qgis_help_text(algorithm))
  cat("\n")
  invisible(algorithm)
}

#' @rdname qgis_show_help
#' @export
qgis_description <- function(algorithm) {
  vapply(
    algorithm,
    function(x) qgis_parsed_help(algorithm)$description,
    character(1)
  )
}

#' @rdname qgis_show_help
#' @export
qgis_arguments <- function(algorithm) {
  qgis_parsed_help(algorithm)$arguments
}

#' @rdname qgis_show_help
#' @export
qgis_outputs <- function(algorithm) {
  qgis_parsed_help(algorithm)$outputs
}

qgis_help_text <- function(algorithm) {
  if (algorithm %in% names(qgisprocess_cache$help_text)) {
    return(qgisprocess_cache$help_text[[algorithm]])
  }

  assert_qgis()
  assert_qgis_algorithm(algorithm)

  result <- qgis_run(
    args = c("help", algorithm)
  )

  qgisprocess_cache$help_text[[algorithm]] <- result$stdout
  result$stdout
}

qgis_parsed_help <- function(algorithm) {
  help_text <- trimws(qgis_help_text(algorithm))

  sec_description <- stringr::str_match(
    help_text,
    stringr::regex(
      "-+\\s+Description\\s+-+\\s+(.*?)\\s+-+\\s+(Arguments|Outputs)",
      dotall = TRUE, multiline = TRUE
    )
  )[, 2, drop = TRUE]

  sec_args <- stringr::str_match(
    help_text,
    stringr::regex(
      "-+\\s+Arguments\\s+-+\\s+(.*?)\\s+-+\\s+Outputs",
      dotall = TRUE, multiline = TRUE
    )
  )[, 2, drop = TRUE]

  sec_args_lines <- stringr::str_trim(readLines(textConnection(sec_args)), side = "right")
  arg_start <- stringr::str_which(sec_args_lines, "^[^\\s]")
  arg_end <- if (length(arg_start) == 0) character(0) else c(arg_start[-1] - 1, length(sec_args_lines))
  arg_text <- unlist(
    Map(
      function(a, b) paste(sec_args_lines[a:b], collapse = "\n"),
      arg_start + 1,
      arg_end
    )
  )

  arg_info <- stringr::str_split(sec_args_lines[arg_start], "\\s*:\\s*", n = 2)
  arg_type <- stringr::str_match(arg_text, "Argument type:\\s*(.+)")[, 2, drop = TRUE]
  arg_sec_available <- stringr::str_match(
    arg_text,
    stringr::regex(
      "Available values:\\s*\\n\\s*-\\s*[0-9]+\\s*:\\s*(.+?)\\s*Acceptable values",
      multiline = TRUE, dotall = TRUE
    )
  )[, 2, drop = TRUE]
  arg_available <- stringr::str_split(arg_sec_available, "\\n\\s*-\\s*[0-9]+\\s*:\\s*")
  arg_available[is.na(arg_sec_available)] <- list(character(0))

  arg_sec_acceptable <- stringr::str_match(
    arg_text,
    stringr::regex("Acceptable values:\\s*\\n\\s*-\\s*(.+)", multiline = TRUE, dotall = TRUE)
  )[, 2, drop = TRUE]
  arg_acceptable <- stringr::str_split(arg_sec_acceptable, "\\n\\s*-\\s*")
  arg_acceptable[is.na(arg_sec_acceptable)] <- list(character(0))

  sec_outputs <- stringr::str_match(
    help_text,
    stringr::regex(
      "-+\\s+Outputs\\s+-+\\s+(.*)",
      dotall = TRUE, multiline = TRUE
    )
  )[, 2, drop = TRUE]

  outputs <- stringr::str_match_all(
    sec_outputs,
    stringr::regex(
      paste0(
        "^([A-Za-z0-9_]+):\\s+<([A-Za-z0-9_ .-]+)>\n\\s([A-Za-z0-9_ .]+)\\s*"),
      dotall = TRUE, multiline = TRUE
    )
  )[[1]]

  # if there are no outputs, there won't be a match here
  outputs <- outputs[!is.na(outputs[, 1, drop = TRUE]), , drop = FALSE]

  list(
    description = sec_description,
    arguments = tibble::tibble(
      name = vapply(arg_info, "[[", 1, FUN.VALUE = character(1)),
      description =  vapply(arg_info, "[[", 2, FUN.VALUE = character(1)),
      qgis_type = arg_type,
      available_values = arg_available,
      acceptable_values = arg_acceptable
    ),
    outputs = tibble::tibble(
      name = outputs[, 2, drop = TRUE],
      description = outputs[, 4, drop = TRUE],
      qgis_output_type = outputs[, 3, drop = TRUE]
    )
  )
}

