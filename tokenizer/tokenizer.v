module tokenizer

import strings

const (
	whitespace = [rune(`\t`), `\n`, `\f`, ` `]
	null = rune(0)

	ascii_upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.runes()
	ascii_lower = 'abcdefghijklmnopqrstuvwxyz'.runes()
	ascii_numeric = '123455678890'.runes()
	ascii_alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.runes()
	ascii_alphanumeric = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.runes()
)

enum TokenizerState {
	after_attr_name
	after_attr_value_quoted
	after_doctype_name
	after_doctype_public_identifier
	after_doctype_public_keyword
	after_doctype_system_identifier
	after_doctype_system_keyword
	ambiguous_ampersand
	attr_name
	attr_value_dbl_quoted
	attr_value_sgl_quoted
	attr_value_unquoted

	before_attr_name
	before_attr_value
	before_doctype_name
	before_doctype_public_identifier
	between_doctype_public_and_system_identifiers
	before_doctype_system_identifier
	bogus_comment
	bogus_doctype

	cdata_section
	cdata_section_bracket
	cdata_section_end
	char_reference
	comment
	comment_end
	comment_end_bang
	comment_end_dash
	comment_lt_sign
	comment_lt_sign_bang
	comment_lt_sign_bang_dash
	comment_lt_sign_bang_dash_dash
	comment_start
	comment_start_dash

	data
	decimal_char_reference
	decimal_char_reference_start
	doctype
	doctype_name
	doctype_public_identifier_dbl_quoted
	doctype_public_identifier_sgl_quoted
	doctype_system_identifier_dbl_quoted
	doctype_system_identifier_sgl_quoted

	end_tag_open
	eof

	hex_char_reference
	hex_char_reference_start

	markup_declaration_open

	named_char_reference
	@none
	num_char_reference
	num_char_reference_end

	plaintext

	rawtext
	rawtext_end_tag_name
	rawtext_end_tag_open
	rawtext_lt_sign
	rcdata
	rcdata_end_tag_name
	rcdata_end_tag_open
	rcdata_lt_sign

	self_closing_start_tag
	script_data
	script_data_double_escape_end
	script_data_double_escape_start
	script_data_double_escaped_dash
	script_data_double_escaped_dash_dash
	script_data_double_escaped_lt_sign
	script_data_end_tag_open
	script_data_escape_start
	script_data_escape_start_dash
	script_data_escaped
	script_data_escaped_dash
	script_data_escaped_dash_dash
	script_data_escaped_end_tag_open
	script_data_escaped_end_tag_name
	script_data_escaped_lt_sign
	script_data_lt_sign

	tag_name
	tag_open
}

struct Tokenizer {
	input []rune
mut:
	return_state TokenizerState = .@none
	state TokenizerState = .data

	cursor int
	curr_input_char rune

	curr_token Token = EOFToken{}

	bldr strings.Builder

	ast Ast
}

fn exit_state_not_implemented(state TokenizerState) {
	println('fn do_state_${state} not implemented. Exiting...')
	exit(1)
}

pub fn new(html []rune) Tokenizer {
	return Tokenizer{
		input: html
	}
}

// gets the next value in buffer and moves the cursor forward once
fn (mut t Tokenizer) next_codepoint() ?rune {
	if t.cursor >= t.input.len {
		return error('End of file.')
	}

	t.cursor++
	return t.input[t.cursor-1]?
}

// gets the next value in buffer
fn (t &Tokenizer) peek_codepoint(offset int) ?rune {
	if t.cursor+offset >= t.input.len {
		return error('End of file.')
	}
	return t.input[t.cursor+offset]
}

[params]
struct SwitchStateParams {
	reconsume bool
}

// saves the current state, changes the state, consumes the next
// character, and invokes the next do_state function.
fn (mut t Tokenizer) switch_state(state TokenizerState, params SwitchStateParams) {
	t.return_state = t.state
	t.state = state

	if !params.reconsume {
		t.curr_input_char = t.next_codepoint() or {
			t.state = .eof
			0
		}
	}
	
	match t.state {
		.data { t.do_state_data() }
		.tag_open { t.do_state_tag_open() }
		.markup_declaration_open { t.do_state_markup_declaration_open() }
		.doctype { t.do_state_doctype() }
		.before_doctype_name { t.do_state_before_doctype_name() }
		.doctype_name { t.do_state_doctype_name() }
		.eof { t.do_state_eof() }
		else { exit_state_not_implemented(t.state) }
	}
}

[params]
struct LookAheadParams {
	case_sensitive bool = true
}

// checks if the next characters match `look_for` and moves the cursor
// forward `look_for.len`. Returns none if next characters do not
// match `look_for`.
fn (mut t Tokenizer) look_ahead(look_for string, params LookAheadParams) ?bool {
	tmp := look_for.runes()
	for i in 0..look_for.len {
		if x := t.peek_codepoint(i) {
			if params.case_sensitive {
				if x != tmp[i] {
					return none
				}
			} else {
				if rune_to_lower(x) != rune_to_lower(tmp[i]) {
					return none
				}
			}
		} else {
			return none
		}
	}
	t.cursor += look_for.len
	return true
}

fn (mut t Tokenizer) push_token(tok Token) {
	t.ast.tokens << tok
}

pub fn (mut t Tokenizer) run() Ast {
	for t.state != .eof {
		t.switch_state(.data)
	}
	return t.ast
}

// functions for each state (alphabetized)


// handles the After DOCTYPE state
//
// see spec:
// https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-name-state
fn (mut t Tokenizer) do_state_after_doctype_name() {
	if t.state == .eof {
		mut token := t.curr_token as DoctypeToken
		token.force_quirks = true
		t.push_token(token)
		t.push_token(EOFToken{
			name: eof_doctype_name
			msg: eof_doctype_msg
		})
	} else if t.curr_input_char in whitespace {
		t.switch_state(.after_doctype_name)
	} else if t.curr_input_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
	} else {
		if _ := t.look_ahead('PUBLIC', case_sensitive: false) {
			t.switch_state(.after_doctype_public_keyword)
		} else if _ := t.look_ahead('SYSTEM', case_sensitive: false) {
			t.switch_state(.after_doctype_system_keyword)
		} else {
			mut token := t.curr_token as DoctypeToken
			token.force_quirks = true
			t.curr_token = Token(token)
			t.switch_state(.bogus_doctype, reconsume: true)
		}
	}
}

// handles the Bogus DOCTYPE state
//
// see spec:
// https://html.spec.whatwg.org/multipage/parsing.html#bogus-doctype-state
fn (mut t Tokenizer) do_state_bogus_doctype() {
	if t.state == .eof {
		t.push_token(t.curr_token)
		t.push_token(EOFToken{
			name: eof_doctype_name
			msg: eof_doctype_msg
		})
	} else if t.curr_input_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
	} else if t.curr_input_char == null {
		println('Parse Error: unexpected null character')
		t.switch_state(.bogus_doctype)
	} else {
		t.switch_state(.bogus_doctype)
	}
}

// 13.2.5.72 Character reference state
//
// see spec:
// https://html.spec.whatwg.org/multipage/parsing.html#character-reference-state
fn (mut t Tokenizer) do_state_char_reference() {
	if t.curr_input_char in ascii_alphanumeric {
		t.switch_state(.named_char_reference, reconsume: true)
	} else if t.curr_input_char == `#` {
		t.bldr.write_rune(t.curr_input_char)
		t.switch_state(.num_char_reference)
	} else {
		// t.flush_code_point
		// t.switch_state(.return)
	}
}

// 13.2.5.73 Named character reference state
//
// see spec:
// https://html.spec.whatwg.org/multipage/parsing.html#named-character-reference-state
fn (mut t Tokenizer) do_state_named_char_reference() {
	if true {

	} else {
		// t.flush_code_point
		// t.switch_state(.return)
	}
}



// needs to be alphabetized

// 13.2.5.1 Data state
fn (mut t Tokenizer) do_state_data() {
	match t.curr_input_char {
		`&` {
			t.bldr = strings.new_builder(0)
			t.bldr.write_rune(`&`)
			t.switch_state(.char_reference)
		}
		`<` {
			t.switch_state(.tag_open)
		}
		null {
			
		}
		else {

		}
	}
}

// 13.2.5.6 Tag open state
fn (mut t Tokenizer) do_state_tag_open() {
	if t.state == .eof {
		t.push_token(CharacterToken{data: `<`})
		t.push_token(EOFToken{
			name: eof_before_tag_name_name
			msg: eof_before_tag_name_msg
		})
	} if t.curr_input_char == `!` {
		t.switch_state(.markup_declaration_open, reconsume: true)
	} else if t.curr_input_char == `/` {
		t.switch_state(.end_tag_open)
	} else if t.curr_input_char in ascii_alpha {
		t.curr_token = Token(TagToken{})
		t.switch_state(.tag_name)
	} else if t.curr_input_char == `?` {
		println('Parser Error: unexpected question mark instead of tag name')
		t.curr_token = Token(CommentToken{})
		t.switch_state(.bogus_comment, reconsume: true)
	} else {
		println('Parser Error: invalid first character of tag name')
		t.push_token(CharacterToken{data: `<`})
		t.switch_state(.data, reconsume: true)
	}
}

fn (mut t Tokenizer) do_state_markup_declaration_open() {
	if _ := t.look_ahead('DOCTYPE') {
		t.switch_state(.doctype)
	} else if _ := t.look_ahead('--') {
		t.switch_state(.comment_start)
	} else if _ := t.look_ahead('[CDATA[') {
		t.switch_state(.cdata_section)
	} else {
		println('Parse Error: Tag cannot open with \'<!\' unless the following characters are \'DOCTYPE\', \'--\', or \'[CDATA[\'.')
		t.switch_state(.bogus_comment)
	}
}

// 13.2.5.53 DOCTYPE state
fn (mut t Tokenizer) do_state_doctype() {
	if t.state == .eof {
		t.push_token(t.curr_token)
		t.push_token(EOFToken{
			name: eof_doctype_name
			msg: eof_doctype_msg
		})
	} else if _likely_(t.curr_input_char in whitespace) {
		t.switch_state(.before_doctype_name)
	} else if t.curr_input_char == `>` {
		t.switch_state(.before_doctype_name, reconsume: true)
	} else {
		println('Parse Error: Missing whitespace before DOCTYPE name')
		t.switch_state(.before_doctype_name, reconsume: true)
	}
}

// 13.2.5.54 Before DOCTYPE name state
fn (mut t Tokenizer) do_state_before_doctype_name() {
	t.curr_token = DoctypeToken{}
	if t.state == .eof {
		t.push_token(t.curr_token)
		t.push_token(EOFToken{
			name: eof_doctype_name
			msg: eof_doctype_msg
		})
	}
	// do this in else clause below
	//else if t.curr_input_char in ascii_upper {
	//	.bldr = strings.new_builder(0)
	//	t.bldr.write_rune(rune_to_lower(t.curr_input_char))
	//}
	else if _unlikely_(t.curr_input_char == null) {
	} else if _unlikely_(t.curr_input_char == `>`) {
		mut token := t.curr_token as DoctypeToken
		token.force_quirks = true
		t.push_token(Token(token))
		t.switch_state(.data)
	} else if t.curr_input_char in whitespace {
		t.switch_state(.before_doctype_name)
	} else {
		t.bldr = strings.new_builder(0)
		t.bldr.write_rune(rune_to_lower(t.curr_input_char))
		t.switch_state(.doctype_name)
	}
}

// 13.2.5.55 DOCTYPE name state
fn (mut t Tokenizer) do_state_doctype_name() {
	if t.state == .eof {
	} else if t.curr_input_char in whitespace {
		t.switch_state(.after_doctype_name)
	} else if t.curr_input_char == `>` {
		mut token := t.curr_token as DoctypeToken
		token.name = t.bldr.str()
		t.push_token(Token(token))
		t.switch_state(.data)
	} else if t.curr_input_char == null {
		println('Parse Error: unexpected null character')
		t.bldr.write_rune(0xfffd) // 0xfffd = �
		t.switch_state(.doctype_name)
	} else {
		t.bldr.write_rune(t.curr_input_char)
		t.switch_state(.doctype_name)
	}
}

[inline]
fn (t &Tokenizer) do_state_eof() {
	println('End of file.')
}