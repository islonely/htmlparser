module tokenizer

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
}