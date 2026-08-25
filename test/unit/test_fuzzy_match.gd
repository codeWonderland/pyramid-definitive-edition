extends GutTest

# Tests FuzzyMatch.matches(), the subsequence matcher behind the draft screen's
# search box.


func test_empty_query_matches_everything() -> void:
	assert_true(FuzzyMatch.matches("", "The Binding of Isaac"), "empty query matches")
	assert_true(FuzzyMatch.matches("   ", "The Binding of Isaac"), "whitespace query matches")


func test_exact_and_substring_match() -> void:
	assert_true(FuzzyMatch.matches("isaac", "The Binding of Isaac"), "substring matches")
	assert_true(
		FuzzyMatch.matches("The Binding of Isaac", "The Binding of Isaac"), "full title matches"
	)


func test_case_insensitive() -> void:
	assert_true(FuzzyMatch.matches("ISAAC", "The Binding of Isaac"), "upper query matches")
	assert_true(FuzzyMatch.matches("isaac", "THE BINDING OF ISAAC"), "upper text matches")


func test_initials_style_subsequence() -> void:
	assert_true(FuzzyMatch.matches("tboi", "The Binding of Isaac"), "initials match in order")
	assert_true(FuzzyMatch.matches("bind", "The Binding of Isaac"), "prefix of a word matches")


func test_order_matters() -> void:
	assert_false(FuzzyMatch.matches("iobt", "The Binding of Isaac"), "out-of-order does not match")


func test_absent_characters_do_not_match() -> void:
	assert_false(FuzzyMatch.matches("zzz", "The Binding of Isaac"), "absent characters fail")


func test_query_longer_than_text_does_not_match() -> void:
	assert_false(FuzzyMatch.matches("a very long query indeed", "Isaac"), "too-long query fails")


func test_leading_and_trailing_whitespace_is_ignored() -> void:
	assert_true(FuzzyMatch.matches("  isaac  ", "The Binding of Isaac"), "query is trimmed")
