extends GutTest

# Tests for source/util/csv_parser.gd


func test_parses_headers_and_rows() -> void:
	var rows = CSVParser.parse_csv("name,multiplayer,coop\nAlpha,yes,no\nBeta,no,yes")

	assert_eq(rows.size(), 2, "two data rows parsed")
	assert_eq(rows[0]["name"], "Alpha")
	assert_eq(rows[0]["multiplayer"], "yes")
	assert_eq(rows[1]["coop"], "yes")


func test_handles_crlf_line_endings() -> void:
	var rows = CSVParser.parse_csv("name,coop\r\nAlpha,yes\r\nBeta,no")

	assert_eq(rows.size(), 2)
	assert_eq(rows[1]["name"], "Beta")


func test_skips_blank_lines() -> void:
	var rows = CSVParser.parse_csv("name,coop\nAlpha,yes\n\nBeta,no\n")

	assert_eq(rows.size(), 2, "blank lines are ignored")


func test_quoted_field_with_comma() -> void:
	var rows = CSVParser.parse_csv('name,desc\nAlpha,"hello, world"')

	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["desc"], "hello, world", "comma inside quotes stays in the field")


func test_row_with_wrong_column_count_is_skipped() -> void:
	var rows = CSVParser.parse_csv("name,coop\nAlpha,yes,extra\nBeta,no")

	assert_eq(rows.size(), 1, "mismatched row is dropped")
	assert_eq(rows[0]["name"], "Beta")


func test_missing_file_returns_empty_array() -> void:
	var rows = CSVParser.parse_file("user://does_not_exist_%d.csv" % randi())

	assert_eq(rows, [], "missing file yields an empty array, not a crash")
	# parse_file intentionally push_error()s on a missing file; mark the expected
	# error handled so it doesn't fail the test.
	var errs = get_errors()
	assert_eq(errs.size(), 1, "exactly one expected error was logged")
	for e in errs:
		e.handled = true
