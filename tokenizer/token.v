module tokenizer

import strings

type Token = CharacterToken | CommentToken | DoctypeToken | EOFToken | TagToken

// as per the html spec "name, public identifier, and system identifier
// must be marked as missing (which is a distinc state from the empty string)".
// It's similar to a null value, but V doesn't have null so we had to come
// up with something else.
const missing = [rune(0), 0, 0, 0].string()

struct DoctypeToken {
pub mut:
	name         string = tokenizer.missing
	public_id    string = tokenizer.missing
	system_id    string = tokenizer.missing
	force_quirks bool
}

struct TagToken {
pub:
	is_start_tag bool = true
pub mut:
	name         string
	self_closing bool
	attr         []Attribute
}

fn (tag &TagToken) is_appropriate(t &Tokenizer) bool {
	if tag.is_start_tag {
		println('Warning: .start_tag type is not meant to be used when invoking is_appropriate fn')
		return false
	}

	if start_tag := t.open_tags.peek() {
		if start_tag.name == tag.name {
			return true
		} else {
			return false
		}
	}

	return false
}

// pub fn (t &TagToken) html() string {
// 	return t.html_depth(0)
// }

// fn (t &TagToken) html_depth(depth int) string {
// 	mut bldr := strings.new_builder(0)
// 	bldr.write_string('  '.repeat(depth))
// 	bldr.write_rune(`<`)
// 	bldr.write_string(t.name)
// 	if t.attr.len > 0 {
// 		for key, val in t.attr {
// 			bldr.write_string(' $key="$val"')
// 		}
// 	}
// 	bldr.write_rune(`>`)

// 	for child in t.children {
// 		bldr.write_string(match child {
// 			TagToken { child.html_depth(depth + 1) }
// 			CharacterToken { child.data.str() }
// 			else { '<unimplemented token>' }
// 		})
// 	}

// 	if !t.self_closing {
// 		bldr.write_string('</$t.name>')
// 	}
// 	return bldr.str()
// }

struct CommentToken {
pub mut:
	data []rune
}

struct CharacterToken {
pub mut:
	data rune
}

struct EOFToken {
	name string    = tokenizer.eof_generic_name
	msg  string    = tokenizer.eof_generic_msg
}

struct Attribute {
pub mut:
	name string
	value string
}

struct AttributeBuilder {
mut:
	name strings.Builder = strings.new_builder(0)
	value strings.Builder = strings.new_builder(0)
}