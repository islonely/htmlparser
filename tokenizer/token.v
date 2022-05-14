module tokenizer

import strings

// end of file errors
const (
	eof_generic_name = 'EOF'
	eof_generic_msg  = 'The end of the file has been reached.'
	eof_doctype_name = 'EOF in doctype.'
	eof_doctype_msg  = 'This error occurs if the parser encounter the end
						of the input stream in a DOCTYPE. In such a case,
						if the DOCTYPE is correctly placed as a document
						preamble, the parser sets the Document to quirks
						mode.'
	eof_before_tag_name_name = 'EOF before tag name.'
	eof_before_tag_name_msg  = 'This error occurs if the parser encounters
								the end of the input stream where a tag
								name is expected. In this case the parser
								treats the beginning of a start tag (i.e., `<`)
								or an end tag (i.e., `</`) as text content.'
	eof_in_tag_name = 'EOF in tag.'
	eof_in_tag_msg  = 'This error occurs if the parser encounters the end
					   of the input stream in a start tag or an end tag
					   (e.g., `<div id=`). Such a tag is ignored.'
	eof_in_script_html_comment_like_text_name = 'EOF in script HTML comment like text.'
	eof_in_script_html_comment_like_text_msg  = 'This error occurs if the parser encounters
												 the end of the input stream in text that
												 resembles an HTML comment inside `script`
												 element content (e.g., `<script><!-- foo`).'
)

enum TokenType {
	doctype
	start_tag
	end_tag
	comment
	character
	eof
}

type Token = CharacterToken | CommentToken | DoctypeToken | EOFToken | TagToken

// as per the html spec "name, public identifier, and system identifier
// must be marked as missing (which is a distinc state from the empty string)".
// It's similar to a null value, but V doesn't have null so we had to come
// up with something else.
const missing = [rune(0), 0, 0, 0].string()

struct DoctypeToken {
	typ TokenType = .doctype
mut:
	name         string = tokenizer.missing
	public_id    string = tokenizer.missing
	system_id    string = tokenizer.missing
	force_quirks bool
}

struct TagToken {
	typ TokenType = .start_tag
mut:
	name         string
	self_closing bool
	attr         map[string]string
	children     []Token
}

fn (tag &TagToken) is_appropriate(t &Tokenizer) bool {
	if _unlikely_(tag.typ == .start_tag) {
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

pub fn (t &TagToken) html() string {
	return t.html_depth(0)
}

fn (t &TagToken) html_depth(depth int) string {
	mut bldr := strings.new_builder(0)
	bldr.write_string('  '.repeat(depth))
	bldr.write_rune(`<`)
	bldr.write_string(t.name)
	if t.attr.len > 0 {
		for key, val in t.attr {
			bldr.write_string(' $key="$val"')
		}
	}
	bldr.write_rune(`>`)

	for child in t.children {
		bldr.write_string(match child {
			TagToken { child.html_depth(depth + 1) }
			CharacterToken { child.data.str() }
			else { '<unimplemented token>' }
		})
	}

	if !t.self_closing {
		bldr.write_string('</$t.name>')
	}
	return bldr.str()
}

struct CommentToken {
	typ TokenType = .comment
mut:
	data []rune
}

struct CharacterToken {
	typ TokenType = .character
mut:
	data rune
}

struct EOFToken {
	typ  TokenType = .eof
	name string    = tokenizer.eof_generic_name
	msg  string    = tokenizer.eof_generic_msg
}
