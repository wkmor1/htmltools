#' Make an HTML object browsable
#'
#' By default, HTML objects display their HTML markup at the console when
#' printed. `browsable` can be used to make specific objects render as HTML
#' by default when printed at the console.
#'
#' You can override the default browsability of an HTML object by explicitly
#' passing `browse = TRUE` (or `FALSE`) to the `print` function.
#'
#' @param x The object to make browsable or not.
#' @param value Whether the object should be considered browsable.
#' @return `browsable` returns `x` with an extra attribute to indicate
#'   that the value is browsable.
#' @export
browsable <- function(x, value = TRUE) {
  attr(x, "browsable_html") <- if (isTRUE(value)) TRUE else NULL
  return(x)
}

#' @return `is.browsable` returns `TRUE` if the value is browsable, or
#'   `FALSE` if not.
#' @rdname browsable
#' @export
is.browsable <- function(x) {
  return(isTRUE(attr(x, "browsable_html", exact=TRUE)))
}

#' Implementation of the print method for HTML
#'
#' Convenience method that provides an implementation of the
#' [base::print()] method for HTML content.
#'
#' @param html HTML content to print
#' @param background Background color for web page
#' @param viewer A function to be called with the URL or path to the generated
#'   HTML page. Can be `NULL`, in which case no viewer will be invoked.
#'
#' @return Invisibly returns the URL or path of the generated HTML page.
#'
#' @export
html_print <- function(html, background = "white", viewer = getOption("viewer", utils::browseURL)) {

  # define temporary directory for output
  www_dir <- tempfile("viewhtml")
  dir.create(www_dir)

  # define output file
  index_html <- file.path(www_dir, "index.html")

  # save file
  save_html(html, file = index_html, background = background, libdir = "lib")

  # show it
  if (!is.null(viewer))
    viewer(index_html)

  invisible(index_html)
}

#' Save an HTML object to a file
#'
#' An S3 generic method for saving an HTML-like object to a file. The default
#' method copies dependency files to the directory specified via `libdir`.
#'
#' @param html HTML content to print.
#' @param file File path or connection. If a file path containing a
#'   sub-directory, the sub-directory must already exist.
#' @param ... Further arguments passed to other methods.
#'
#' @export
save_html <- function(html, file, ...) {
  UseMethod("save_html")
}

#' @rdname save_html
#' @param background Background color for web page.
#' @param libdir Directory to copy dependencies to.
#' @param lang Value of the `<html>` `lang` attribute.
#' @export
save_html.default <- function(html, file, background = "white", libdir = "lib", lang = "en", ...) {
  rlang::check_dots_empty()

  force(html)
  force(background)
  force(libdir)

  # ensure that the paths to dependencies are relative to the base
  # directory where the webpage is being built.
  if (is.character(file)) {
    dir <- normalizePath(dirname(file), mustWork = TRUE)
    file <- file.path(dir, basename(file))
    owd <- setwd(dir)
    on.exit(setwd(owd), add = TRUE)
  }

  rendered <- renderTags(html)

  deps <- lapply(rendered$dependencies, function(dep) {
    dep <- copyDependencyToDir(dep, libdir, FALSE)
    dep <- makeDependencyRelative(dep, dir, FALSE)
    dep
  })

  bodyBegin <- if (!isTRUE(grepl("<body\\b", rendered$html[1], ignore.case = TRUE))) {
    "<body>"
  }
  bodyEnd <- if (!is.null(bodyBegin)) {
    "</body>"
  }

  # build the web-page
  html <- c("<!DOCTYPE html>",
            sprintf('<html lang="%s">', lang),
            "<head>",
            "<meta charset=\"utf-8\">",
            sprintf("<style>body{background-color:%s;}</style>", htmlEscape(background)),
            renderDependencies(deps, c("href", "file")),
            rendered$head,
            "</head>",
            bodyBegin,
            rendered$html,
            bodyEnd,
            "</html>")

  if (is.character(file)) {
    # Write to file in binary mode, so \r\n in input doesn't become \r\r\n
    con <- base::file(file, open = "w+b")
    on.exit(close(con), add = TRUE)
  } else {
    con <- file
  }

  # write it
  writeLines(html, con, useBytes = TRUE)
}


