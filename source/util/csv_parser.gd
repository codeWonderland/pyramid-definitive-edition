class_name CSVParser


static func parse_csv(csv_data: String) -> Array:
	var lines = "\n".join(csv_data.split("\r\n")).split("\n")  # Handle both \r\n and \n
	var result = []
	var headers = Array(lines[0].split(",")).map(func(header): return header.replace('"', ""))

	for i in range(1, lines.size()):
		var current_line = lines[i]

		if current_line == "":
			continue

		var entry = {}
		var in_quotes = false
		var current_value = ""
		var values = []

		for j in range(current_line.length()):
			var current_char = current_line[j]

			if current_char == '"':  # Handle double quotes for escaping
				in_quotes = !in_quotes
			elif current_char == "," and not in_quotes:
				values.append(current_value.strip_edges(true, true).replace("\'", "'"))
				current_value = ""
			else:
				current_value += current_char

		values.append(current_value.strip_edges(true, true).replace("\'", "'"))  # Add the last value

		if values.size() != headers.size():
			push_warning(
				(
					"Row "
					+ str(i + 1)
					+ " has a different number of values ("
					+ str(values.size())
					+ ") than headers ("
					+ str(headers.size())
					+ "). Skipping row."
				)
			)
			continue  # Skip the row if there's a mismatch

		for j in range(headers.size()):
			entry[headers[j]] = values[j]
		result.append(entry)

	return result


static func parse_file(file_path: String) -> Array:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: " + file_path)
		return []  # Return empty array on error

	var content = file.get_as_text()
	file.close()
	return parse_csv(content)
