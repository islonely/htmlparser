module tokenizer

const(
	eof_doctype_name = 'EOF in doctype.'
	eof_doctype_msg = 'This error occurs if the parser encounter the end
						of the input stream in a DOCTYPE. In such a case,
						if the DOCTYPE is correctly placed as a document
						preamble, the parser sets the Document to quirks
						mode.'
	eof_before_tag_name_name = 'EOF before tag name.'
	eof_before_tag_name_msg = 'This error occurs if the parser encounters
								the end of the input stream where a tag
								name is expected. In this case the parser
								treats the beginning of a start tag (i.e., <)
								or an end tag (i.e., </) as text content.'

)

enum TokenType {
	doctype
	start_tag
	end_tag
	comment
	character
	eof
}

type Token = DoctypeToken | TagToken | CommentToken | CharacterToken | EOFToken

// as per the html spec "name, public identifier, and system identifier
// must be marked as missing (which is a distinc state from the empty string)".
// It's similar to a null value, but V doesn't have null so we had to come
// up with something else.
const missing = [rune(0), 0, 0, 0].string()
struct DoctypeToken {
	typ TokenType	 = .doctype
mut:
	name string		 = missing
	public_id string = missing
	system_id string = missing
	force_quirks bool
}

struct TagToken {
	typ TokenType = .start_tag
mut:
	name string
	self_closing bool
	attr map[string]string
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
	typ TokenType = .eof
	name string
	msg string
}