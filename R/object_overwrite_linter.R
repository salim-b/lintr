#' Block assigning any variables whose name clashes with a `base` R function
#'
#' Re-using existing names creates a risk of subtle error best avoided.
#'   Avoiding this practice also encourages using better, more descriptive names.
#'
#' @param packages Character vector of packages to search for names that should
#'   be avoided. Defaults to the most common default packages: base, stats,
#'   utils, tools, methods, graphics, and grDevices.
#' @param allow_names Character vector of object names to ignore, i.e., which
#'   are allowed to collide with exports from `packages`.
#'
#' @examples
#' # will produce lints
#' code <- "function(x) {\n  data <- x\n  data\n}"
#' writeLines(code)
#' lint(
#'   text = code,
#'   linters = object_overwrite_linter()
#' )
#'
#' code <- "function(x) {\n  lint <- 'fun'\n  lint\n}"
#' writeLines(code)
#' lint(
#'   text = code,
#'   linters = object_overwrite_linter(packages = "lintr")
#' )
#'
#' # okay
#' code <- "function(x) {\n  data('mtcars')\n}"
#' writeLines(code)
#' lint(
#'   text = code,
#'   linters = object_overwrite_linter()
#' )
#'
#' code <- "function(x) {\n  data <- x\n  data\n}"
#' writeLines(code)
#' lint(
#'   text = code,
#'   linters = object_overwrite_linter(packages = "base")
#' )
#'
#' # names in function signatures are ignored
#' lint(
#'   text = "function(data) data <- subset(data, x > 0)",
#'   linters = object_overwrite_linter()
#' )
#'
#' @evalRd rd_tags("object_overwrite_linter")
#' @seealso
#'  - [linters] for a complete list of linters available in lintr.
#'  - <https://style.tidyverse.org/syntax.html#object-names>
#' @export
object_overwrite_linter <- function(
    packages = c("base", "stats", "utils", "tools", "methods", "graphics", "grDevices"),
    allow_names = character()) {
  for (package in packages) {
    if (!requireNamespace(package, quietly = TRUE)) {
      stop("Package '", package, "' is not available.")
    }
  }
  pkg_exports <- lapply(
    packages,
    # .__C__ etc.: drop 150+ "virtual" names since they are very unlikely to appear anyway
    function(pkg) setdiff(grep("^[.]__[A-Z]__", getNamespaceExports(pkg), value = TRUE, invert = TRUE), allow_names)
  )
  pkg_exports <- data.frame(
    package = rep(packages, lengths(pkg_exports)),
    name = unlist(pkg_exports),
    stringsAsFactors = FALSE
  )

  # test that the symbol doesn't match an argument name in the function
  # NB: data.table := has parse token LEFT_ASSIGN as well
  xpath <- glue("
    //SYMBOL[
      not(text() = ancestor::expr/preceding-sibling::SYMBOL_FORMALS/text())
      and ({ xp_text_in_table(pkg_exports$name) })
    ]/
      parent::expr[
        count(*) = 1
        and (
          following-sibling::LEFT_ASSIGN[text() != ':=']
          or following-sibling::EQ_ASSIGN
          or preceding-sibling::RIGHT_ASSIGN
        )
        and ancestor::*[
          (self::expr or self::expr_or_assign_or_help or self::equal_assign)
          and (preceding-sibling::FUNCTION or preceding-sibling::OP-LAMBDA)
        ]
      ]
  ")

  Linter(function(source_expression) {
    if (!is_lint_level(source_expression, "expression")) {
      return(list())
    }

    xml <- source_expression$xml_parsed_content

    bad_expr <- xml_find_all(xml, xpath)
    bad_symbol <- xml_text(xml_find_first(bad_expr, "SYMBOL"))
    source_pkg <- pkg_exports$package[match(bad_symbol, pkg_exports$name)]
    lint_message <-
      sprintf("'%s' is an exported object from package '%s'. Avoid re-using such symbols.", bad_symbol, source_pkg)

    xml_nodes_to_lints(
      bad_expr,
      source_expression = source_expression,
      lint_message = lint_message,
      type = "warning"
    )
  })
}