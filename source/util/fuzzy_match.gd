class_name FuzzyMatch

## Subsequence matching for the draft screen's search box: a query matches when
## all of its characters appear in the text in order, though not necessarily
## next to each other. So "tboi" finds "The Binding of Isaac" and "isaac" finds
## it too, without the player having to type a title exactly.
##
## Matching is case-insensitive and used purely as a filter — ranking is left to
## the screen's own sort so search never fights the chosen A-Z/Z-A order.


## True when every character of `query` appears in `text` in order. An empty or
## whitespace-only query matches everything, so clearing the box shows all packs.
static func matches(query: String, text: String) -> bool:
	var needle := query.strip_edges().to_lower()
	if needle.is_empty():
		return true

	var haystack := text.to_lower()
	if needle.length() > haystack.length():
		return false

	var needle_index := 0
	for haystack_index in range(haystack.length()):
		if haystack[haystack_index] != needle[needle_index]:
			continue

		needle_index += 1
		if needle_index == needle.length():
			return true

	return false
