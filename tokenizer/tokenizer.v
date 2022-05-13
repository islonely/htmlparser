module tokenizer

import datatypes { Stack }
import strings

const (
	whitespace = [rune(`\t`), `\n`, `\f`, ` `]
	null = rune(0)
	replacement_token = CharacterToken{data: 0xfffd}

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
mut:
	return_state Stack<TokenizerState>
	state TokenizerState = .data

	cursor int
	curr_char rune

	curr_token Token = EOFToken{}

	bldr strings.Builder
pub mut:
	input []rune
	ast Ast
}

fn exit_state_not_implemented(state TokenizerState) {
	println('fn do_state_${state} not implemented. Exiting...')
	exit(1)
}

pub fn new() Tokenizer {
	return Tokenizer{}
}

// gets the next value in buffer and moves the cursor forward once
fn (mut t Tokenizer) next_codepoint() ?rune {
	if t.cursor >= t.input.len {
		t.state = .eof
		return error('End of file.')
	}

	t.cursor++
	return t.input[t.cursor-1]
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
	return_to TokenizerState = .@none
}

// saves the current state, changes the state, consumes the next
// character, and invokes the next do_state function.
fn (mut t Tokenizer) switch_state(state TokenizerState, params SwitchStateParams) {
	t.state = state
	
	match t.state {
		.after_attr_name { t.do_state_after_attr_name() }
		.after_attr_value_quoted { t.do_state_after_attr_value_quoted() }
		.attr_name { t.do_state_attr_name() }
		.attr_value_dbl_quoted { t.do_state_attr_value_dbl_quoted() }
		.attr_value_sgl_quoted { t.do_state_attr_value_sgl_quoted() }
		.attr_value_unquoted { t.do_state_attr_value_unquoted() }
		.bogus_comment { t.do_state_bogus_comment() }
		.data { t.do_state_data() }
		.doctype { t.do_state_doctype() }
		.before_attr_name { t.do_state_before_attr_name() }
		.before_attr_value { t.do_state_before_attr_value() }
		.before_doctype_name { t.do_state_before_doctype_name() }
		.doctype_name { t.do_state_doctype_name() }
		.eof { t.do_state_eof() }
		.end_tag_open { t.do_state_end_tag_open() }
		.markup_declaration_open { t.do_state_markup_declaration_open() }
		.self_closing_start_tag { t.do_state_self_closing_start_tag() }
		.tag_name { t.do_state_tag_name() }
		.tag_open { t.do_state_tag_open() }
		else { exit_state_not_implemented(t.state) }
	}

	if params.return_to != .@none {
		t.switch_state(params.return_to)
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

pub fn (mut t Tokenizer) run(html []rune) Ast {
	t.input = html
	for t.state != .eof {
		t.switch_state(.data)
	}
	return t.ast
}

[inline]
fn (t &Tokenizer) do_state_eof() {
	println('End of file.')
}

fn (t &Tokenizer) parse_error(typ ParseError) {
	println('Parse Error: $typ')
}

// functions for each state organized how they appear here
// https://html.spec.whatwg.org/multipage/parsing.html

// 13.2.5.1
fn (mut t Tokenizer) do_state_data() {
	t.curr_char = t.next_codepoint() or {
		t.push_token(EOFToken{
			name: 'EOF'
			msg: 'End of file has been reached.'
		})
		return
	}

	if t.curr_char == `&` {
		t.switch_state(.char_reference, return_to: .data)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.tag_open)
		return
	}

	if _unlikely_(t.curr_char == null) {
		t.parse_error(.unexpected_null_character)
	}

	t.push_token(CharacterToken{data: t.curr_char})
}

// 13.2.5.2
fn (mut t Tokenizer) do_state_rcdata() {
	t.curr_char = t.next_codepoint() or {
		t.push_token(EOFToken{
			name: 'EOF'
			msg: 'End of file has been reached.'
		})
		return
	}

	if t.curr_char == `&` {
		t.switch_state(.char_reference, return_to: .rcdata)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.rcdata_lt_sign)
		return
	}

	if _unlikely_(t.curr_char == null) {
		t.push_token(replacement_token)
	}

	t.push_token(CharacterToken{data: t.curr_char})
}