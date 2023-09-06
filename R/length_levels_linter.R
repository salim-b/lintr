#' Require usage of nlevels over length(levels(.))
#'
#' `length(levels(x))` is the same as `nlevels(x)`, but harder to read.
#'
#' @examples
#' # will produce lints
#' lint(
#'   text = "length(levels(x))",
#'   linters = length_levels_linter()
#' )
#'
#' # okay
#' lint(
#'   text = "length(c(levels(x), levels(y)))",
#'   linters = length_levels_linter()
#' )
#'
#' @evalRd rd_tags("length_levels_linter")
#' @seealso [linters] for a complete list of linters available in lintr.
#' @export
length_levels_linter <- function() {
  xpath <- "
  //SYMBOL_FUNCTION_CALL[text() = 'levels']
    /parent::expr
    /parent::expr
    /parent::expr[expr/SYMBOL_FUNCTION_CALL[text() = 'length']]
  "

  Linter(function(source_expression) {
    if (!is_lint_level(source_expression, "expression")) {
      return(list())
    }

    xml <- source_expression$xml_parsed_content

    bad_expr <- xml_find_all(xml, xpath)

    xml_nodes_to_lints(
      bad_expr,
      source_expression = source_expression,
      lint_message = "nlevels(x) is better than length(levels(x)).",
      type = "warning"
    )
  })
}