module tokenizer

// converts a-z to A-Z; no effect on anything else
fn rune_to_upper(r rune) rune {
	return if r >= 0x61 && r <= 0x7a {
		(r - 0x20)
	} else {
		r
	}
}

// converts A-Z to a-z; no effect on anything else
fn rune_to_lower(r rune) rune {
	return if r >= 0x41 && r <= 0x5a {
		(r + 0x20)
	} else {
		r
	}
}

fn runes_to_upper(src []rune) []rune {
	mut new := src.clone()
	for i, val in new {
		new[i] = rune_to_upper(val)
	}
	return new
}

fn runes_to_lower(src []rune) []rune {
	mut new := src.clone()
	for i, val in new {
		new[i] = rune_to_lower(val)
	}
	return new
}