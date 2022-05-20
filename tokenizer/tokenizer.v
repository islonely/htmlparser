module tokenizer

import datatypes { Stack }
import strings

const (
	whitespace        = [rune(`\t`), `\n`, `\f`, ` `]
	null              = rune(0)
	replacement_token = CharacterToken{
		data: 0xfffd
	}

	ascii_upper        = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.runes()
	ascii_lower        = 'abcdefghijklmnopqrstuvwxyz'.runes()
	ascii_numeric      = '123455678890'.runes()
	ascii_alpha        = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.runes()
	ascii_alphanumeric = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.runes()

	hex_digits = 'abcdefABCDEF0123456789'.runes()
	dec_digits = '0123456789'.runes()
)

enum TokenizerState {
	@none
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
	script_data_double_escaped
	script_data_double_escape_end
	script_data_double_escape_start
	script_data_double_escaped_dash
	script_data_double_escaped_dash_dash
	script_data_double_escaped_lt_sign
	script_data_end_tag_name
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
	state        TokenizerState = .data

	cursor    int
	curr_char rune

	curr_attr  AttributeBuilder
	curr_token Token = EOFToken{}
	open_tags  Stack<TagToken>

	char_ref_code int

	bldr strings.Builder = strings.new_builder(0)

	input  []rune
	tokens []Token
}

fn exit_state_not_implemented(state TokenizerState) {
	println('fn do_state_$state not implemented. Exiting...')
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
	return t.input[t.cursor - 1]
}

// gets the next value in buffer
fn (t &Tokenizer) peek_codepoint(offset int) ?rune {
	if t.cursor + offset >= t.input.len {
		return error('End of file.')
	}
	return t.input[t.cursor + offset]
}

[params]
struct SwitchStateParams {
	return_to TokenizerState = .@none
	reconsume bool
}

// saves the current state, changes the state, consumes the next
// character, and invokes the next do_state function.
fn (mut t Tokenizer) switch_state(state TokenizerState, params SwitchStateParams) {
	t.state = state

	if params.reconsume {
		t.cursor--
	}

	if params.return_to != .@none {
		t.return_state.push(params.return_to)
	}

	match t.state {
		.after_attr_name { t.do_state_after_attr_name() }
		.after_attr_value_quoted { t.do_state_after_attr_value_quoted() }
		.after_doctype_name { t.do_state_after_doctype_name() }
		.after_doctype_public_identifier { t.do_state_after_doctype_public_identifier() }
		.after_doctype_public_keyword { t.do_state_after_doctype_public_keyword() }
		.after_doctype_system_identifier { t.do_state_after_doctype_system_identifier() }
		.after_doctype_system_keyword { t.do_state_after_doctype_system_keyword() }
		.ambiguous_ampersand { t.do_state_ambiguous_ampersand() }
		.attr_name { t.do_state_attr_name() }
		.attr_value_dbl_quoted { t.do_state_attr_value_dbl_quoted() }
		.attr_value_sgl_quoted { t.do_state_attr_value_sgl_quoted() }
		.attr_value_unquoted { t.do_state_attr_value_unquoted() }
		.before_attr_name { t.do_state_before_attr_name() }
		.before_attr_value { t.do_state_before_attr_value() }
		.before_doctype_name { t.do_state_before_doctype_name() }
		.before_doctype_public_identifier { t.do_state_before_doctype_public_identifier() }
		.between_doctype_public_and_system_identifiers { t.do_state_between_doctype_public_and_system_identifiers() }
		.before_doctype_system_identifier { t.do_state_before_doctype_system_identifier() }
		.bogus_comment { t.do_state_bogus_comment() }
		.bogus_doctype { t.do_state_bogus_doctype() }
		.cdata_section { t.do_state_cdata_section() }
		.cdata_section_bracket { t.do_state_cdata_section_bracket() }
		.cdata_section_end { t.do_state_cdata_section_end() }
		.char_reference { t.do_state_char_reference() }
		.comment { t.do_state_comment() }
		.comment_end { t.do_state_comment_end() }
		.comment_end_bang { t.do_state_comment_end_bang() }
		.comment_end_dash { t.do_state_comment_end_dash() }
		.comment_lt_sign { t.do_state_comment_lt_sign() }
		.comment_lt_sign_bang { t.do_state_comment_lt_sign_bang() }
		.comment_lt_sign_bang_dash { t.do_state_comment_lt_sign_bang_dash() }
		.comment_lt_sign_bang_dash_dash { t.do_state_comment_lt_sign_bang_dash_dash() }
		.comment_start { t.do_state_comment_start() }
		.comment_start_dash { t.do_state_comment_start_dash() }
		.data { t.do_state_data() }
		.decimal_char_reference { t.do_state_decimal_char_reference() }
		.decimal_char_reference_start { t.do_state_decimal_char_reference_start() }
		.doctype { t.do_state_doctype() }
		.doctype_name { t.do_state_doctype_name() }
		.doctype_public_identifier_dbl_quoted { t.do_state_doctype_public_identifier_dbl_quoted() }
		.doctype_public_identifier_sgl_quoted { t.do_state_doctype_public_identifier_sgl_quoted() }
		.doctype_system_identifier_dbl_quoted { t.do_state_doctype_system_identifier_dbl_quoted() }
		.doctype_system_identifier_sgl_quoted { t.do_state_doctype_system_identifier_sgl_quoted() }
		.end_tag_open { t.do_state_end_tag_open() }
		.eof { t.do_state_eof() }
		.hex_char_reference { t.do_state_hex_char_reference() }
		.hex_char_reference_start { t.do_state_hex_char_reference_start() }
		.markup_declaration_open { t.do_state_markup_declaration_open() }
		.named_char_reference { t.do_state_named_char_reference() }
		.num_char_reference { t.do_state_num_char_reference() }
		.num_char_reference_end { t.do_state_num_char_reference_end() }
		.plaintext { t.do_state_plaintext() }
		.rawtext { t.do_state_rawtext() }
		.rawtext_end_tag_name { t.do_state_rawtext_end_tag_name() }
		.rawtext_end_tag_open { t.do_state_rawtext_end_tag_open() }
		.rawtext_lt_sign { t.do_state_rawtext_lt_sign() }
		.rcdata { t.do_state_rcdata() }
		.rcdata_end_tag_name { t.do_state_rcdata_end_tag_name() }
		.rcdata_end_tag_open { t.do_state_rcdata_end_tag_open() }
		.rcdata_lt_sign { t.do_state_rcdata_lt_sign() }
		.self_closing_start_tag { t.do_state_self_closing_start_tag() }
		.script_data { t.do_state_script_data() }
		.script_data_double_escaped { t.do_state_script_data_double_escaped() }
		.script_data_double_escape_end { t.do_state_script_data_double_escape_end() }
		.script_data_double_escape_start { t.do_state_script_data_double_escape_start() }
		.script_data_double_escaped_dash { t.do_state_script_data_double_escaped_dash() }
		.script_data_double_escaped_dash_dash { t.do_state_script_data_double_escaped_dash_dash() }
		.script_data_double_escaped_lt_sign { t.do_state_script_data_double_escaped_lt_sign() }
		.script_data_end_tag_name { t.do_state_script_data_end_tag_name() }
		.script_data_end_tag_open { t.do_state_script_data_end_tag_open() }
		.script_data_escape_start { t.do_state_script_data_escape_start() }
		.script_data_escape_start_dash { t.do_state_script_data_escape_start_dash() }
		.script_data_escaped { t.do_state_script_data_escaped() }
		.script_data_escaped_dash { t.do_state_script_data_escaped_dash() }
		.script_data_escaped_dash_dash { t.do_state_script_data_escaped_dash_dash() }
		.script_data_escaped_end_tag_open { t.do_state_script_data_escaped_end_tag_open() }
		.script_data_escaped_end_tag_name { t.do_state_script_data_escaped_end_tag_name() }
		.script_data_escaped_lt_sign { t.do_state_script_data_escaped_lt_sign() }
		.script_data_lt_sign { t.do_state_script_data_lt_sign() }
		.tag_name { t.do_state_tag_name() }
		.tag_open { t.do_state_tag_open() }
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
	for i in 0 .. look_for.len {
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

[inline]
fn (mut t Tokenizer) push_token(tok Token) {
	t.tokens << tok
}

[inline]
fn (mut t Tokenizer) push_char() {
	t.push_rune(t.curr_char)
}

[inline]
fn (mut t Tokenizer) push_rune(r rune) {
	t.push_token(CharacterToken{ data: r })
}

[inline]
fn (mut t Tokenizer) push_string(str string) {
	for r in str.runes() {
		t.push_rune(r)
	}
}

[inline]
fn (mut t Tokenizer) push_eof(tok EOFToken) {
	t.push_token(tok)
}

fn (mut t Tokenizer) flush_codepoints() {
	if state := t.return_state.peek() {
		if state in [
			.attr_value_dbl_quoted,
			.attr_value_sgl_quoted,
			.attr_value_unquoted
		] {
			t.curr_attr.value.write_string(t.bldr.str())
		} else {
			t.push_string(t.bldr.str())
		}
	} else {
		t.push_string(t.bldr.str())
	}
}

pub fn (mut t Tokenizer) run(html []rune) []Token {
	t.input = html
	for t.state != .eof {
		t.switch_state(.data)
	}
	return t.tokens
}

[inline]
fn (t &Tokenizer) do_state_eof() {
	println('End of file.')
}

fn (t &Tokenizer) parse_error(typ ParseError) {
	println('Parse Error: $typ')
}

fn (mut t Tokenizer) do_return_state(reconsume bool) {
	if state := t.return_state.pop() {
		t.switch_state(state, reconsume: reconsume)
	} else {
		println('Parse Error: No return state set. This should never happen. Switching to data state.')
		t.switch_state(.data, reconsume: reconsume)
	}
}

// functions for each state organized how they appear here
// https://html.spec.whatwg.org/multipage/parsing.html

// 13.2.5.1
fn (mut t Tokenizer) do_state_data() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
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

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.data)
		return
	}

	t.push_char()
}

// 13.2.5.2
fn (mut t Tokenizer) do_state_rcdata() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
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

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.rcdata)
		return
	}

	t.push_char()
}

// 13.2.5.3
fn (mut t Tokenizer) do_state_rawtext() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.rawtext)
		return
	}

	t.push_char()
}

// 13.2.5.4
fn (mut t Tokenizer) do_state_script_data() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.script_data_lt_sign)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data)
		return
	}

	t.push_char()
}

// 13.2.5.5
fn (mut t Tokenizer) do_state_plaintext() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.plaintext)
		return
	}

	t.push_char()
}

// 13.2.5.6
fn (mut t Tokenizer) do_state_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_before_tag_name)
		t.push_rune(`<`)
		t.push_eof(
			name: eof_before_tag_name_name
			msg: eof_before_tag_name_msg
		)
		return
	}

	if t.curr_char == `!` {
		t.switch_state(.markup_declaration_open)
		return
	}

	if t.curr_char == `/` {
		t.switch_state(.end_tag_open)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{}
		t.switch_state(.tag_name, reconsume: true)
		return
	}

	if t.curr_char == `?` {
		t.parse_error(.unexpected_question_mark_instead_of_tag_name)
		t.switch_state(.bogus_comment, reconsume: true)
		return
	}

	t.parse_error(.invalid_first_character_of_tag_name)
	t.push_rune(`<`)
	t.switch_state(.data, reconsume: true)
}

// 13.2.5.7
fn (mut t Tokenizer) do_state_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_before_tag_name)
		t.push_string('</')
		t.push_eof(
			name: eof_before_tag_name_name
			msg: eof_before_tag_name_msg
		)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			is_start_tag: false
		}
		t.switch_state(.tag_name, reconsume: true)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.missing_end_tag_name)
		t.switch_state(.data)
		return
	}

	t.parse_error(.invalid_first_character_of_tag_name)
	t.curr_token = CommentToken{}
	t.switch_state(.bogus_comment, reconsume: true)
}

// 13.2.5.8
fn (mut t Tokenizer) do_state_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_tag)
		t.push_eof(
			name: eof_in_tag_name
			msg: eof_in_tag_msg
		)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		t.switch_state(.before_attr_name)
		return
	}

	if t.curr_char == `/` {
		t.switch_state(.self_closing_start_tag)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		if (t.curr_token as TagToken).is_start_tag {
			t.open_tags.push(t.curr_token as TagToken)
		}
		t.switch_state(.data)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		mut tok := t.curr_token as TagToken
		tok.name += rune(0xfffd).str()
		t.curr_token = tok
		t.switch_state(.tag_name)
		return
	}

	mut tok := t.curr_token as TagToken
	tok.name += rune_to_lower(t.curr_char).str()
	t.curr_token = tok
	t.switch_state(.tag_name)
}

// 13.2.5.9
fn (mut t Tokenizer) do_state_rcdata_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.push_rune(`<`)
		t.switch_state(.rcdata, reconsume: true)
		return
	}

	if t.curr_char == `/` {
		t.bldr = strings.new_builder(0)
		t.switch_state(.rcdata_end_tag_open)
		return
	}

	t.push_rune(`<`)
	t.switch_state(.rcdata, reconsume: true)
}

// 13.2.5.10
fn (mut t Tokenizer) do_state_rcdata_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.switch_state(.rcdata, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			is_start_tag: false
		}
		t.switch_state(.rcdata_end_tag_name, reconsume: true)
	}

	t.push_rune(`<`)
	t.push_token(CharacterToken{ data: `/` })
	t.switch_state(.rcdata, reconsume: true)
}

// 13.2.5.11
fn (mut t Tokenizer) do_state_rcdata_end_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.push_string(t.bldr.str())
		t.switch_state(.rcdata, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.before_attr_name)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rcdata, reconsume: true)
		}
		return
	}

	if t.curr_char == `/` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.self_closing_start_tag)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rcdata, reconsume: true)
		}
		return
	}

	if t.curr_char == `>` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.push_token(t.curr_token)
			t.switch_state(.data)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rcdata, reconsume: true)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		mut tok := t.curr_token as TagToken
		tok.name += rune_to_lower(t.curr_char).str()
		t.curr_token = tok
		t.bldr.write_rune(t.curr_char)
		t.switch_state(.rcdata_end_tag_name)
		return
	}

	t.push_string('</')
	t.push_string(t.bldr.str())
	t.switch_state(.rcdata, reconsume: true)
}

// 13.2.5.12
fn (mut t Tokenizer) do_state_rawtext_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.push_rune(`<`)
		t.switch_state(.rawtext, reconsume: true)
		return
	}

	if t.curr_char == `/` {
		t.bldr = strings.new_builder(0)
		t.switch_state(.rawtext_end_tag_open)
		return
	}

	t.push_rune(`<`)
	t.switch_state(.rawtext, reconsume: true)
	return
}

// 13.2.5.13
fn (mut t Tokenizer) do_state_rawtext_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.switch_state(.rawtext, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			is_start_tag: false
		}
		t.switch_state(.rawtext_end_tag_name, reconsume: true)
		return
	}

	t.push_string('</')
	t.switch_state(.rawtext, reconsume: true)
}

// 13.2.5.14
fn (mut t Tokenizer) do_state_rawtext_end_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.push_string(t.bldr.str())
		t.switch_state(.rawtext, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.before_attr_name)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rawtext, reconsume: true)
		}
		return
	}

	if t.curr_char == `/` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.self_closing_start_tag)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rawtext, reconsume: true)
		}
		return
	}

	if t.curr_char == `>` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.push_token(t.curr_token)
			t.switch_state(.data)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rawtext, reconsume: true)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		mut tok := t.curr_token as TagToken
		tok.name += rune_to_lower(t.curr_char).str()
		t.curr_token = tok
		t.bldr.write_rune(t.curr_char)
		t.switch_state(.rawtext_end_tag_name)
		return
	}

	t.push_string('</')
	t.push_string(t.bldr.str())
	t.switch_state(.rawtext, reconsume: true)
}

// 13.2.5.15
fn (mut t Tokenizer) do_state_script_data_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.push_rune(`<`)
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char == `/` {
		t.bldr = strings.new_builder(0)
		t.switch_state(.script_data_end_tag_open)
		return
	}

	if t.curr_char == `!` {
		t.push_string('<!')
		t.switch_state(.script_data_escape_start)
		return
	}

	t.push_rune(`<`)
	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.16
fn (mut t Tokenizer) do_state_script_data_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			is_start_tag: false
		}
		t.switch_state(.script_data_end_tag_name, reconsume: true)
		return
	}

	t.push_string('</')
	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.17
fn (mut t Tokenizer) do_state_script_data_end_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.push_string(t.bldr.str())
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.before_attr_name)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data, reconsume: true)
		}
		return
	}

	if t.curr_char == `/` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.self_closing_start_tag)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data, reconsume: true)
		}
		return
	}

	if t.curr_char == `<` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.push_token(t.curr_token)
			t.switch_state(.data)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data, reconsume: true)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		mut tok := t.curr_token as TagToken
		tok.name += rune_to_lower(t.curr_char).str()
		t.curr_token = tok
		t.bldr.write_rune(t.curr_char)
		return
	}

	t.push_string('</')
	t.push_string(t.bldr.str())
	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.18
fn (mut t Tokenizer) do_state_script_data_escape_start() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escape_start_dash)
		return
	}

	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.19
fn (mut t Tokenizer) do_state_script_data_escape_start_dash() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escaped_dash_dash)
		return
	}

	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.20
fn (mut t Tokenizer) do_state_script_data_escaped() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escaped_dash)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.script_data_escaped_lt_sign)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data_escaped)
		return
	}

	t.push_char()
	t.switch_state(.script_data_escaped)
}

// 13.2.5.21
fn (mut t Tokenizer) do_state_script_data_escaped_dash() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escaped_dash_dash)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.script_data_escaped_lt_sign)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data_escaped)
		return
	}

	t.push_char()
	t.switch_state(.script_data_escaped)
}

// 13.2.5.22
fn (mut t Tokenizer) do_state_script_data_escaped_dash_dash() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escaped_dash_dash)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.script_data_escaped_lt_sign)
		return
	}

	if t.curr_char == `>` {
		t.push_rune(`>`)
		t.switch_state(.script_data)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data)
		return
	}

	t.push_char()
	t.switch_state(.script_data_escaped)
}

// 13.2.5.23
fn (mut t Tokenizer) do_state_script_data_escaped_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.push_rune(`<`)
		t.switch_state(.script_data_escaped, reconsume: true)
		return
	}

	if t.curr_char == `/` {
		t.bldr = strings.new_builder(0)
		t.switch_state(.script_data_escaped_end_tag_open)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.bldr = strings.new_builder(0)
		t.push_rune(`<`)
		t.switch_state(.script_data_double_escape_start)
		return
	}

	t.push_rune(`<`)
	t.switch_state(.script_data_escaped, reconsume: true)
}

// 13.2.5.24
fn (mut t Tokenizer) do_state_script_data_escaped_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.switch_state(.script_data_escaped, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			is_start_tag: false
		}
		t.switch_state(.script_data_escaped_end_tag_name, reconsume: true)
		return
	}

	t.push_string('</')
	t.switch_state(.script_data_escaped, reconsume: true)
}

// 13.2.5.25
fn (mut t Tokenizer) do_state_script_data_escaped_end_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.push_string(t.bldr.str())
		t.switch_state(.script_data_escaped, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.before_attr_name)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data_escaped, reconsume: true)
		}
		return
	}

	if t.curr_char == `/` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.self_closing_start_tag)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data_escaped, reconsume: true)
		}
		return
	}

	if t.curr_char == `>` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.push_token(t.curr_token)
			t.switch_state(.data)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data_escaped, reconsume: true)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		mut tok := t.curr_token as TagToken
		tok.name += rune_to_lower(t.curr_char).str()
		t.curr_token = tok
		t.bldr.write_rune(t.curr_char)
		t.switch_state(.script_data_escaped_end_tag_name)

		return
	}

	t.push_string('</')
	t.push_string(t.bldr.str())
	t.switch_state(.script_data_escaped, reconsume: true)
}

// 13.2.5.26
fn (mut t Tokenizer) do_state_script_data_double_escape_start() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.script_data_escaped, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace || t.curr_char in [`/`, `>`] {
		// after calling strings.Builder.str() it clears the memory at the location
		// where the string was stored, so the Builder needs to be reset
		buf := t.bldr.str()
		t.bldr = strings.new_builder(buf.len)
		t.bldr.write_string(buf)

		if buf == 'script' {
			t.switch_state(.script_data_double_escaped)
		} else {
			t.push_char()
			t.switch_state(.script_data_escaped)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.bldr.write_rune(rune_to_lower(t.curr_char))
		t.push_char()
		t.switch_state(.script_data_double_escape_start)
		return
	}

	t.switch_state(.script_data_escaped, reconsume: true)
}

// 13.2.5.27
fn (mut t Tokenizer) do_state_script_data_double_escaped() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_double_escaped_dash)
		return
	}

	if t.curr_char == `<` {
		t.push_rune(`<`)
		t.switch_state(.script_data_double_escaped_lt_sign)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		return
	}

	t.push_char()
	t.switch_state(.script_data_double_escaped)
}

// 13.2.5.28
fn (mut t Tokenizer) do_state_script_data_double_escaped_dash() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_double_escaped_dash_dash)
		return
	}

	if t.curr_char == `<` {
		t.push_rune(`<`)
		t.switch_state(.script_data_double_escaped_lt_sign)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data_double_escaped)
		return
	}

	t.push_char()
	t.switch_state(.script_data_double_escaped)
}

// 13.2.5.29
fn (mut t Tokenizer) do_state_script_data_double_escaped_dash_dash() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		return
	}

	if t.curr_char == `<` {
		t.push_rune(`<`)
		t.switch_state(.script_data_double_escaped_lt_sign)
		return
	}

	if t.curr_char == `>` {
		t.push_rune(`>`)
		t.switch_state(.script_data)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data_double_escaped)
		return
	}

	t.push_char()
	t.switch_state(.script_data_double_escaped)
}

// 13.2.5.30
fn (mut t Tokenizer) do_state_script_data_double_escaped_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.script_data_double_escaped, reconsume: true)
		return
	}

	if t.curr_char == `/` {
		t.bldr = strings.new_builder(0)
		t.push_rune(`/`)
		t.switch_state(.script_data_double_escape_end)
		return
	}

	t.switch_state(.script_data_double_escaped, reconsume: true)
}

// 13.2.5.31
fn (mut t Tokenizer) do_state_script_data_double_escape_end() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.script_data_double_escaped, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace || t.curr_char in [`/`, `>`] {
		buf := t.bldr.str()
		t.bldr = strings.new_builder(buf.len)
		t.bldr.write_string(buf)

		if buf == 'script' {
			t.switch_state(.script_data_escaped)
		} else {
			t.push_char()
			t.switch_state(.script_data_double_escaped)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.bldr.write_rune(rune_to_lower(t.curr_char))
		t.push_char()
		return
	}

	t.switch_state(.script_data_double_escaped, reconsume: true)
}

// 13.2.5.32
fn (mut t Tokenizer) do_state_before_attr_name() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.after_attr_name, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		t.switch_state(.before_attr_name)
		return
	}

	if t.curr_char in [`/`, `>`] {
		t.switch_state(.after_attr_name, reconsume: true)
		return
	}

	if t.curr_char == `=` {
		t.parse_error(.unexpected_equals_sign_before_attr_name)
		t.curr_attr = AttributeBuilder{}
		t.curr_attr.name.write_rune(t.curr_char)
		t.switch_state(.attr_name)
		return
	}

	t.curr_attr = AttributeBuilder{}
	t.switch_state(.attr_name, reconsume: true)
}

// 13.2.5.33
fn (mut t Tokenizer) do_state_attr_name() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.after_attr_name, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace || t.curr_char == `/` || t.curr_char == `>` {
		t.switch_state(.after_attr_name, reconsume: true)
		return
	}

	if t.curr_char == `=` {
		t.switch_state(.before_attr_value)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.curr_attr.name.write_rune(0xfffd)
		t.switch_state(.attr_name)
		return
	}

	if t.curr_char in [`"`, `'`, `<`] {
		t.parse_error(.unexpected_char_in_attr_name)
	}

	t.curr_attr.name.write_rune(rune_to_lower(t.curr_char))
	t.switch_state(.attr_name)
}

// 13.2.5.34
fn (mut t Tokenizer) do_state_after_attr_name() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_tag)
		t.push_eof(
			name: eof_in_tag_name
			msg: eof_in_tag_msg
		)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		t.switch_state(.after_attr_name)
		return
	}

	if t.curr_char == `/` {
		t.switch_state(.self_closing_start_tag)
		return
	}

	if t.curr_char == `=` {
		t.switch_state(.before_attr_value)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	t.curr_attr = AttributeBuilder{}
	t.switch_state(.attr_name, reconsume: true)
}

// 13.2.5.35
fn (mut t Tokenizer) do_state_before_attr_value() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.attr_value_unquoted, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		t.switch_state(.before_attr_value)
		return
	}

	if t.curr_char == `"` {
		t.switch_state(.attr_value_dbl_quoted)
		return
	}

	if t.curr_char == `'` {
		t.switch_state(.attr_value_sgl_quoted)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.missing_attr_value)
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	t.switch_state(.attr_value_unquoted, reconsume: true)
}

// 13.2.5.36
fn (mut t Tokenizer) do_state_attr_value_dbl_quoted() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_tag)
		t.push_eof(
			name: eof_in_tag_name
			msg: eof_in_tag_msg
		)
		return
	}

	if t.curr_char == `"` {
		t.switch_state(.after_attr_value_quoted)
		return
	}

	if t.curr_char == `&` {
		t.switch_state(.char_reference, return_to: .attr_value_dbl_quoted)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.curr_attr.value.write_rune(0xfffd)
		t.switch_state(.attr_value_dbl_quoted)
		return
	}

	t.curr_attr.value.write_rune(t.curr_char)
	t.switch_state(.attr_value_dbl_quoted)
}

// 13.2.5.37
fn (mut t Tokenizer) do_state_attr_value_sgl_quoted() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_tag)
		t.push_eof(
			name: eof_in_tag_name
			msg: eof_in_tag_msg
		)
		return
	}

	if t.curr_char == `'` {
		t.switch_state(.after_attr_value_quoted)
		return
	}

	if t.curr_char == `&` {
		t.switch_state(.char_reference, return_to: .attr_value_sgl_quoted)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.curr_attr.value.write_rune(0xfffd)
		t.switch_state(.attr_value_sgl_quoted)
		return
	}

	t.curr_attr.value.write_rune(t.curr_char)
	t.switch_state(.attr_value_sgl_quoted)
}

// 13.2.5.38
fn (mut t Tokenizer) do_state_attr_value_unquoted() {
	mut tok := t.curr_token as TagToken
	tok.attr << Attribute{
		name: t.curr_attr.name.str()
		value: t.curr_attr.value.str()
	}
	t.curr_token = tok

	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_tag)
		t.push_eof(
			name: eof_in_tag_name
			msg: eof_in_tag_msg
		)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		t.switch_state(.before_attr_name)
		return
	}

	if t.curr_char == `&` {
		t.switch_state(.char_reference, return_to: .attr_value_unquoted)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.curr_attr.value.write_rune(0xfffd)
		t.switch_state(.attr_value_unquoted)
		return
	}

	if t.curr_char in [`"`, `'`, `<`, `=`, `\``] {
		t.parse_error(.unexpected_char_in_unquoted_attr_value)
		// t.push_char()
		t.curr_attr.value.write_rune(t.curr_char)
		t.switch_state(.attr_value_unquoted)
		return
	}

	t.curr_attr.value.write_rune(t.curr_char)
	t.switch_state(.attr_value_unquoted)
}

// 13.2.5.39
fn (mut t Tokenizer) do_state_after_attr_value_quoted() {
	mut tok := t.curr_token as TagToken
	tok.attr << Attribute{
		name: t.curr_attr.name.str()
		value: t.curr_attr.value.str()
	}
	t.curr_token = tok

	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_tag)
		t.push_eof(
			name: eof_in_tag_name
			msg: eof_in_tag_msg
		)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		t.switch_state(.before_attr_name)
		return
	}

	if t.curr_char == `/` {
		t.switch_state(.self_closing_start_tag)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	t.parse_error(.missing_whitespace_between_attr)
	t.switch_state(.before_attr_name, reconsume: true)
}

// 13.2.5.40
fn (mut t Tokenizer) do_state_self_closing_start_tag() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_tag)
		t.push_eof(
			name: eof_in_tag_name
			msg: eof_in_tag_msg
		)
		return
	}

	if t.curr_char == `>` {
		mut tok := t.curr_token as TagToken
		tok.self_closing = true
		t.push_token(tok)
		t.switch_state(.data)
		return
	}

	t.parse_error(.unexpected_solidus_in_tag)
	t.switch_state(.before_attr_name, reconsume: true)
}

// 13.2.5.41
fn (mut t Tokenizer) do_state_bogus_comment() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		mut tok := t.curr_token as CommentToken
		tok.data << 0xfffd
		t.curr_token = tok
		return
	}

	mut tok := t.curr_token as CommentToken
	tok.data << t.curr_char
	t.curr_token = tok
}

// 13.2.5.42
fn (mut t Tokenizer) do_state_markup_declaration_open() {
	// t.curr_char = t.next_codepoint() or {
	// 	t.parse_error(.incorrectly_opened_comment)
	// 	t.curr_token = CommentToken{}
	// 	t.switch_state(.bogus_comment, reconsume: true)
	// 	return
	// }

	if _ := t.look_ahead('--') {
		t.curr_token = CommentToken{}
		t.switch_state(.comment_start)
		return
	}

	if _ := t.look_ahead('DOCTYPE', case_sensitive: false) {
		t.switch_state(.doctype)
		return
	}

	if _ := t.look_ahead('[CDATA[') {
		// TODO: I'm not sure exactly what I'm suppose to do here.
		// I've never used CDATA in HTML and never seen it used, so I
		// assume that means it can be put on the back burner.

		// From the specs page:
		// "If there is an adjusted current node and it is not an
		// element in the HTML namespace, then switch to the CDATA section
		// state. Otherwise, this is a cdata-in-html-content parse error.
		// Create a comment token whose data is the '[CDATA[' string.
		// Switch to the bogus comment state."
		if false {
			t.switch_state(.cdata_section)
		} else {
			t.parse_error(.cdata_in_html_content)
			t.curr_token = CommentToken{
				data: '[CDATA['.runes()
			}
			t.switch_state(.bogus_comment)
		}
		return
	}

	t.parse_error(.incorrectly_opened_comment)
	t.curr_token = CommentToken{}
	t.switch_state(.bogus_comment, reconsume: true)
}

// 13.2.5.43
fn (mut t Tokenizer) do_state_comment_start() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.comment, reconsume: true)
		return
	}

	if t.curr_char == `-` {
		t.switch_state(.comment_start_dash)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.abrupt_closing_of_empty_comment)
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	t.switch_state(.comment, reconsume: true)
}

// 13.2.5.44
fn (mut t Tokenizer) do_state_comment_start_dash() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_comment)
		t.push_token(t.curr_token)
		t.push_eof(
			name: eof_in_comment_name
			msg: eof_in_comment_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.switch_state(.comment)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.abrupt_closing_of_empty_comment)
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	mut tok := t.curr_token as CommentToken
	tok.data << `-`
	t.curr_token = tok
	t.switch_state(.comment, reconsume: true)
}

// 13.2.5.45
fn (mut t Tokenizer) do_state_comment() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_comment)
		t.push_token(t.curr_token)
		t.push_eof(
			name: eof_in_comment_name
			msg: eof_in_comment_msg
		)
		return
	}

	if t.curr_char == `<` {
		mut tok := t.curr_token as CommentToken
		tok.data << t.curr_char
		t.curr_token = tok
		t.switch_state(.comment_lt_sign)
		return
	}

	if t.curr_char == `-` {
		t.switch_state(.comment_end_dash)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		mut tok := t.curr_token as CommentToken
		tok.data << 0xfffd
		t.curr_token = tok
		return
	}

	mut tok := t.curr_token as CommentToken
	tok.data << t.curr_char
	t.curr_token = tok
}

// 13.2.5.46
fn (mut t Tokenizer) do_state_comment_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.comment, reconsume: true)
		return
	}

	if t.curr_char == `!` {
		mut tok := t.curr_token as CommentToken
		tok.data << t.curr_char
		t.curr_token = tok
		t.switch_state(.comment_lt_sign_bang)
		return
	}

	if t.curr_char == `<` {
		mut tok := t.curr_token as CommentToken
		tok.data << t.curr_char
		t.curr_token = tok
		t.switch_state(.comment_lt_sign)
		return
	}

	t.switch_state(.comment, reconsume: true)
}

// 13.2.5.47
fn (mut t Tokenizer) do_state_comment_lt_sign_bang() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.comment, reconsume: true)
		return
	}

	if t.curr_char == `-` {
		t.switch_state(.comment_lt_sign_bang_dash)
		return
	}

	t.switch_state(.comment, reconsume: true)
}

// 13.2.5.48
fn (mut t Tokenizer) do_state_comment_lt_sign_bang_dash() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.comment_end_dash, reconsume: true)
		return
	}

	if t.curr_char == `-` {
		t.switch_state(.comment_lt_sign_bang_dash_dash)
		return
	}

	t.switch_state(.comment_end_dash, reconsume: true)
}

// 13.2.5.49
fn (mut t Tokenizer) do_state_comment_lt_sign_bang_dash_dash() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.comment_end, reconsume: true)
		return
	}

	if t.curr_char == `>` {
		t.switch_state(.comment_end, reconsume: true)
		return
	}

	t.parse_error(.nested_comment)
	t.switch_state(.comment_end)
}

// 13.2.5.50
fn (mut t Tokenizer) do_state_comment_end_dash() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_comment)
		t.push_token(t.curr_token)
		t.push_eof(
			name: eof_in_comment_name
			msg: eof_in_comment_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.switch_state(.comment_end)
		return
	}

	mut tok := t.curr_token as CommentToken
	tok.data << `-`
	t.switch_state(.comment, reconsume: true)
}

// 13.2.5.51
fn (mut t Tokenizer) do_state_comment_end() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_comment)
		t.push_token(t.curr_token)
		t.push_eof(
			name: eof_in_comment_name
			msg: eof_in_comment_msg
		)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	if t.curr_char == `!` {
		t.switch_state(.comment_end_bang)
		return
	}
	
	if t.curr_char == `-` {
		mut tok := t.curr_token as CommentToken
		tok.data << `-`
		t.curr_token = tok
		t.switch_state(.comment_end)
		return
	}

	mut tok := t.curr_token as CommentToken
	tok.data << '--'.runes()
	t.switch_state(.comment, reconsume: true)
}

// 13.2.5.52
fn (mut t Tokenizer) do_state_comment_end_bang() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_comment)
		t.push_token(t.curr_token)
		t.push_eof(
			name: eof_in_comment_name
			msg: eof_in_comment_msg
		)
		return
	}

	if t.curr_char == `-` {
		mut tok := t.curr_token as CommentToken
		tok.data << '--!'.runes()
		t.curr_token = tok
		t.switch_state(.comment_end_dash)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.incorrectly_closed_comment)
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	mut tok := t.curr_token as CommentToken
	tok.data << '--!'.runes()
	t.switch_state(.comment, reconsume: true)
}

// 13.2.5.53
fn (mut t Tokenizer) do_state_doctype() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		t.curr_token = DoctypeToken{force_quirks: true}
		t.push_token(t.curr_token)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.before_doctype_name)
		return
	}

	if t.curr_char == `>` {
		t.switch_state(.before_doctype_name, reconsume: true)
		return
	}

	t.parse_error(.missing_whitespace_before_doctype_name)
	t.switch_state(.before_doctype_name, reconsume: true)
}

// 13.2.5.54
fn (mut t Tokenizer) do_state_before_doctype_name() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.missing_doctype_name)
		t.curr_token = DoctypeToken{force_quirks: true}
		t.push_token(t.curr_token)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.before_doctype_name)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		t.curr_token = DoctypeToken{name: rune(0xfffd).str()}
		t.switch_state(.doctype_name)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.missing_doctype_name)
		t.curr_token = DoctypeToken{force_quirks: true}
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	t.curr_token = DoctypeToken{name: t.curr_char.str()}
	t.switch_state(.doctype_name)
}

// 13.2.5.55
fn (mut t Tokenizer) do_state_doctype_name() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.unexpected_null_character)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.after_doctype_name)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	if t.curr_char == tokenizer.null {
		t.parse_error(.unexpected_null_character)
		mut tok := t.curr_token as DoctypeToken
		tok.name += rune(0xfffd).str()
		t.curr_token = tok
		t.switch_state(.doctype_name)
		return
	}

	mut tok := t.curr_token as DoctypeToken
	tok.name += t.curr_char.str()
	t.curr_token = tok
	t.switch_state(.doctype_name)
}

// 13.2.5.56
fn (mut t Tokenizer) do_state_after_doctype_name() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.after_doctype_name)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	if _ := t.look_ahead('PUBLIC', case_sensitive: false) {
		t.switch_state(.after_doctype_public_keyword)
		return
	}

	if _ := t.look_ahead('SYSTEM', case_sensitive: false) {
		t.switch_state(.after_doctype_system_keyword)
		return
	}

	t.parse_error(.invalid_char_sequence_after_doctype_name)
	mut tok := t.curr_token as DoctypeToken
	tok.force_quirks = true
	t.switch_state(.bogus_doctype, reconsume: true)
}

// 13.2.5.57
fn (mut t Tokenizer) do_state_after_doctype_public_keyword() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.before_doctype_public_identifier)
		return
	}

	if t.curr_char == `"` {
		t.parse_error(.missing_whitespace_after_doctype_public_keyword)
		mut tok := t.curr_token as DoctypeToken
		tok.public_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_public_identifier_dbl_quoted)
		return
	}

	if t.curr_char == `'` {
		t.parse_error(.missing_whitespace_after_doctype_public_keyword)
		mut tok := t.curr_token as DoctypeToken
		tok.public_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_public_identifier_sgl_quoted)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.missing_doctype_public_identifier)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.switch_state(.data)
		return
	}

	t.parse_error(.missing_quote_before_doctype_public_identifier)
	mut tok := t.curr_token as DoctypeToken
	tok.force_quirks = true
	t.curr_token = tok
	t.switch_state(.bogus_doctype, reconsume: true)
}

// 13.2.5.58
fn (mut t Tokenizer) do_state_before_doctype_public_identifier() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(t.curr_token)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.before_doctype_public_identifier)
		return
	}

	if t.curr_char == `"` {
		mut tok := t.curr_token as DoctypeToken
		tok.public_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_public_identifier_dbl_quoted)
		return
	}

	if t.curr_char == `'` {
		mut tok := t.curr_token as DoctypeToken
		tok.public_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_public_identifier_sgl_quoted)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.missing_doctype_public_identifier)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.switch_state(.data)
		return
	}

	t.parse_error(.missing_quote_before_doctype_public_identifier)
	mut tok := t.curr_token as DoctypeToken
	tok.force_quirks = true
	t.curr_token = tok
	t.switch_state(.bogus_doctype, reconsume: true)
}

// 13.2.5.59
fn (mut t Tokenizer) do_state_doctype_public_identifier_dbl_quoted() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		t.switch_state(.data)
		return
	}

	if t.curr_char == `"` {
		t.switch_state(.after_doctype_public_identifier)
		return
	}

	if t.curr_char == null {
		t.parse_error(.unexpected_null_character)
		mut tok := t.curr_token as DoctypeToken
		tok.public_id += rune(0xfffd).str()
		t.curr_token = tok
		t.switch_state(.doctype_public_identifier_dbl_quoted)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.abrupt_doctype_public_identifier)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.switch_state(.data)
		return
	}

	mut tok := t.curr_token as DoctypeToken
	tok.public_id += t.curr_char.str()
	t.curr_token = tok
	t.switch_state(.doctype_public_identifier_dbl_quoted)
}

// 13.2.5.60
fn (mut t Tokenizer) do_state_doctype_public_identifier_sgl_quoted() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		t.switch_state(.data)
		return
	}

	if t.curr_char == `'` {
		t.switch_state(.after_doctype_public_identifier)
		return
	}

	if t.curr_char == null {
		t.parse_error(.unexpected_null_character)
		mut tok := t.curr_token as DoctypeToken
		tok.public_id += rune(0xfffd).str()
		t.curr_token = tok
		t.switch_state(.doctype_public_identifier_sgl_quoted)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.abrupt_doctype_public_identifier)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.switch_state(.data)
		return
	}

	mut tok := t.curr_token as DoctypeToken
	tok.public_id += t.curr_char.str()
	t.curr_token = tok
	t.switch_state(.doctype_public_identifier_sgl_quoted)
}

// 13.2.5.61
fn (mut t Tokenizer) do_state_after_doctype_public_identifier() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_name
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.between_doctype_public_and_system_identifiers)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	if t.curr_char == `"` {
		t.parse_error(.missing_whitespace_between_doctype_public_and_system_identifiers)
		mut tok := t.curr_token as DoctypeToken
		tok.system_id = ''
		t.switch_state(.doctype_system_identifier_dbl_quoted)
		return
	}

	if t.curr_char == `'` {
		t.parse_error(.missing_whitespace_between_doctype_public_and_system_identifiers)
		mut tok := t.curr_token as DoctypeToken
		tok.system_id = ''
		t.switch_state(.doctype_system_identifier_sgl_quoted)
		return
	}

	t.parse_error(.missing_quote_before_doctype_system_identifier)
	mut tok := t.curr_token as DoctypeToken
	tok.force_quirks = true
	t.switch_state(.bogus_doctype, reconsume: true)
}

// 13.2.5.62
fn (mut t Tokenizer) do_state_between_doctype_public_and_system_identifiers() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.between_doctype_public_and_system_identifiers)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	if t.curr_char == `"` {
		mut tok := t.curr_token as DoctypeToken
		tok.system_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_system_identifier_dbl_quoted)
		return
	}

	if t.curr_char == `'` {
		mut tok := t.curr_token as DoctypeToken
		tok.system_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_system_identifier_sgl_quoted)
		return
	}

	t.parse_error(.missing_quote_before_doctype_system_identifier)
	mut tok := t.curr_token as DoctypeToken
	tok.force_quirks = true
	t.curr_token = tok
	t.switch_state(.bogus_doctype, reconsume: true)
}

// 13.2.5.63
fn (mut t Tokenizer) do_state_after_doctype_system_keyword() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.before_doctype_system_identifier)
		return
	}

	if t.curr_char == `"` {
		t.parse_error(.missing_whitespace_after_doctype_system_keyword)
		mut tok := t.curr_token as DoctypeToken
		tok.system_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_system_identifier_dbl_quoted)
		return
	}

	if t.curr_char == `'` {
		t.parse_error(.missing_whitespace_after_doctype_system_keyword)
		mut tok := t.curr_token as DoctypeToken
		tok.system_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_system_identifier_sgl_quoted)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.missing_doctype_system_identifier)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.switch_state(.data)
		return
	}

	t.parse_error(.missing_quote_before_doctype_system_identifier)
	mut tok := t.curr_token as DoctypeToken
	tok.force_quirks = true
	t.curr_token = tok
	t.switch_state(.bogus_doctype, reconsume: true)
}

// 13.2.5.64
fn (mut t Tokenizer) do_state_before_doctype_system_identifier() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.before_doctype_system_identifier)
		return
	}

	if t.curr_char == `"` {
		mut tok := t.curr_token as DoctypeToken
		tok.system_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_system_identifier_dbl_quoted)
		return
	}

	if t.curr_char == `'` {
		mut tok := t.curr_token as DoctypeToken
		tok.system_id = ''
		t.curr_token = tok
		t.switch_state(.doctype_system_identifier_sgl_quoted)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.missing_doctype_system_identifier)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.switch_state(.data)
		return
	}

	t.parse_error(.missing_quote_before_doctype_system_identifier)
	mut tok := t.curr_token as DoctypeToken
	tok.force_quirks = true
	t.curr_token = tok
	t.switch_state(.bogus_doctype, reconsume: true)
}

// 13.2.5.65
fn (mut t Tokenizer) do_state_doctype_system_identifier_dbl_quoted() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char == `"` {
		t.switch_state(.after_doctype_system_identifier)
		return
	}

	if t.curr_char == null {
		t.parse_error(.unexpected_null_character)
		mut tok := t.curr_token as DoctypeToken
		tok.system_id += rune(0xfffd).str()
		t.curr_token = tok
		t.switch_state(.doctype_system_identifier_dbl_quoted)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.abrupt_doctype_system_identifier)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.switch_state(.data)
		return
	}

	mut tok := t.curr_token as DoctypeToken
	tok.system_id += t.curr_char.str()
	t.curr_token = tok
	t.switch_state(.doctype_system_identifier_dbl_quoted)
}

// 13.2.5.66
fn (mut t Tokenizer) do_state_doctype_system_identifier_sgl_quoted() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char == `'` {
		t.switch_state(.after_doctype_system_identifier)
		return
	}

	if t.curr_char == null {
		t.parse_error(.unexpected_null_character)
		mut tok := t.curr_token as DoctypeToken
		tok.system_id += rune(0xfffd).str()
		t.curr_token = tok
		t.switch_state(.doctype_system_identifier_sgl_quoted)
		return
	}

	if t.curr_char == `>` {
		t.parse_error(.abrupt_doctype_system_identifier)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.switch_state(.data)
		return
	}

	mut tok := t.curr_token as DoctypeToken
	tok.system_id += t.curr_char.str()
	t.curr_token = tok
	t.switch_state(.doctype_system_identifier_sgl_quoted)
}

// 13.2.5.67
fn (mut t Tokenizer) do_state_after_doctype_system_identifier() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_doctype)
		mut tok := t.curr_token as DoctypeToken
		tok.force_quirks = true
		t.push_token(tok)
		t.push_eof(
			name: eof_in_doctype_name
			msg: eof_in_doctype_msg
		)
		return
	}

	if t.curr_char in whitespace {
		t.switch_state(.after_doctype_system_identifier)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.switch_state(.data)
		return
	}

	t.parse_error(.unexpected_char_after_doctype_system_identifier)
	t.switch_state(.bogus_doctype, reconsume: true)
}

// 13.2.5.68
fn (mut t Tokenizer) do_state_bogus_doctype() {
	t.curr_char = t.next_codepoint() or {
		t.push_token(t.curr_token)
		t.push_eof(EOFToken{})
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		t.push_eof(EOFToken{})
		return
	}

	if t.curr_char == null {
		t.parse_error(.unexpected_null_character)
		t.switch_state(.bogus_doctype)
		return
	}

	t.switch_state(.bogus_doctype)
}

// 13.2.5.69
fn (mut t Tokenizer) do_state_cdata_section() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_cdata)
		t.push_eof(
			name: eof_in_cdata_name
			msg: eof_in_cdata_msg
		)
		return
	}

	if t.curr_char == `]` {
		t.switch_state(.cdata_section_bracket)
		return
	}

	t.push_char()
	t.switch_state(.cdata_section)
}

// 13.2.5.70
fn (mut t Tokenizer) do_state_cdata_section_bracket() {
	t.curr_char = t.next_codepoint() or {
		t.push_rune(`]`)
		t.switch_state(.cdata_section, reconsume: true)
		return
	}

	if t.curr_char == `]` {
		t.switch_state(.cdata_section_end)
		return
	}

	t.push_rune(`]`)
	t.switch_state(.cdata_section, reconsume: true)
}

// 13.2.5.71
fn (mut t Tokenizer) do_state_cdata_section_end() {
	t.curr_char = t.next_codepoint() or {
		t.push_string(']]')
		t.switch_state(.cdata_section)
		return
	}

	if t.curr_char == `]` {
		t.push_rune(`]`)
		t.switch_state(.cdata_section_end)
		return
	}

	if t.curr_char == `>` {
		t.switch_state(.data)
		return
	}

	t.push_string(']]')
	t.switch_state(.cdata_section, reconsume: true)
}

// 13.2.5.72
fn (mut t Tokenizer) do_state_char_reference() {
	t.bldr = strings.new_builder(0)
	t.bldr.write_rune(`&`)

	t.curr_char = t.next_codepoint() or {
		t.flush_codepoints()
		t.do_return_state(true)
		return
	}

	if t.curr_char in ascii_alphanumeric {
		t.switch_state(.named_char_reference, reconsume: true)
		return
	}

	if t.curr_char == `#` {
		t.bldr.write_rune(t.curr_char)
		t.switch_state(.num_char_reference)
		return
	}

	t.flush_codepoints()
	t.do_return_state(true)
}

// 13.2.5.73
// NOTE: I'm having trouble understanding exactly what this state
// is does, so something may be implemented incorrectly here. I
// tried my best though. Here's where it's referenced in the HTML
// spec though: https://html.spec.whatwg.org/multipage/parsing.html#hexadecimal-character-reference-state:character-reference-code
fn (mut t Tokenizer) do_state_named_char_reference() {
	mut ref := ''
	for {
		t.curr_char = t.next_codepoint() or {
			break
		}

		if t.curr_char == `;` {
			ref += ';'
			t.bldr.write_rune(`;`)
			break
		}

		if ref in char_ref.keys() {
			t.cursor--
			break
		}

		if t.curr_char !in ascii_alphanumeric {
			t.cursor--
			break
		}

		ref += t.curr_char.str()
		t.bldr.write_rune(t.curr_char)
	}
	last := ref.runes().last()

	if ref in char_ref.keys() {
		state := t.return_state.peek() or {
			println('Parse Error: Return state should always be set while parsing a character reference. Treating absence as ambiguous ampersand.')
			t.flush_codepoints()
			t.switch_state(.ambiguous_ampersand)
			return
		}

		next_char := t.peek_codepoint(1) or { null }

		if state in [
					.attr_value_dbl_quoted,
					.attr_value_sgl_quoted,
					.attr_value_unquoted
				]
				&& last != `;`
				&& (next_char in ascii_alphanumeric || next_char == `=`) {
			t.flush_codepoints()
			t.do_return_state(false)
		} else {
			if last != `;` {
				t.parse_error(.missing_semicolon_after_char_reference)
			}

			t.bldr = strings.new_builder(2)
			t.bldr.write_string(char_ref[ref].string())
			// println(t.bldr.str())
			t.flush_codepoints()
			t.do_return_state(false)
		}
	} else {
		t.flush_codepoints()
		t.switch_state(.ambiguous_ampersand)
	}
}

// 13.2.5.74
fn (mut t Tokenizer) do_state_ambiguous_ampersand() {
	t.curr_char = t.next_codepoint() or {
		t.do_return_state(true)
		return
	}

	if t.curr_char in ascii_alphanumeric {
		state := t.return_state.peek() or { TokenizerState.@none }
		if state in [
			.attr_value_dbl_quoted,
			.attr_value_sgl_quoted,
			.attr_value_unquoted
		] {
			t.curr_attr.value.write_rune(t.curr_char)
		} else {
			t.push_rune(t.curr_char)
		}
		t.switch_state(.ambiguous_ampersand)
		return
	}

	if t.curr_char == `;` {
		t.parse_error(.unknown_named_char_reference)
		t.do_return_state(true)
		return
	}

	t.do_return_state(true)
}

// 13.2.5.75
fn (mut t Tokenizer) do_state_num_char_reference() {
	t.char_ref_code = 0
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.decimal_char_reference_start, reconsume: true)
		return
	}

	if t.curr_char in [`x`, `X`] {
		t.bldr.write_rune(t.curr_char)
		t.switch_state(.hex_char_reference_start)
		return
	}

	t.switch_state(.decimal_char_reference_start, reconsume: true)
}

// 13.2.5.76
fn (mut t Tokenizer) do_state_hex_char_reference_start() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.absence_of_digits_in_num_char_reference)
		t.flush_codepoints()
		t.do_return_state(true)
		return
	}

	if t.curr_char in hex_digits {
		t.switch_state(.hex_char_reference, reconsume: true)
		return
	}

	t.parse_error(.absence_of_digits_in_num_char_reference)
	t.flush_codepoints()
	t.do_return_state(true)
}

// 13.2.5.77
fn (mut t Tokenizer) do_state_decimal_char_reference_start() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.absence_of_digits_in_num_char_reference)
		t.flush_codepoints()
		t.do_return_state(true)
		return
	}

	if t.curr_char in dec_digits {
		t.switch_state(.decimal_char_reference, reconsume: true)
		return
	}

	t.parse_error(.absence_of_digits_in_num_char_reference)
	t.flush_codepoints()
	t.do_return_state(true)
}

// 13.2.5.78
fn (mut t Tokenizer) do_state_hex_char_reference() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.missing_semicolon_after_char_reference)
		t.switch_state(.num_char_reference_end, reconsume: true)
		return
	}

	if t.curr_char in dec_digits {
		t.char_ref_code *= 16
		t.char_ref_code += int(t.curr_char - 0x0030)
		t.switch_state(.hex_char_reference)
		return
	}

	if t.curr_char in 'ABCDEF'.runes() {
		t.char_ref_code *= 16
		t.char_ref_code += int(t.curr_char - 0x0037)
		t.switch_state(.hex_char_reference)
		return
	}

	if t.curr_char in 'abcdef'.runes() {
		t.char_ref_code *= 16
		t.char_ref_code += int(t.curr_char - 0x0057)
		t.switch_state(.hex_char_reference)
		return
	}

	if t.curr_char == `;` {
		t.switch_state(.num_char_reference_end)
	}

	t.parse_error(.missing_semicolon_after_char_reference)
	t.switch_state(.num_char_reference_end, reconsume: true)
}

// 13.2.5.79
fn (mut t Tokenizer) do_state_decimal_char_reference() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.missing_semicolon_after_char_reference)
		t.switch_state(.num_char_reference_end, reconsume: true)
		return
	}

	if t.curr_char in dec_digits {
		t.char_ref_code *= 16
		t.char_ref_code += int(t.curr_char - 0x0030)
		t.switch_state(.decimal_char_reference)
		return
	}

	if t.curr_char == `;` {
		t.switch_state(.num_char_reference_end)
		return
	}

	t.parse_error(.missing_semicolon_after_char_reference)
	t.switch_state(.num_char_reference_end, reconsume: true)
}

// 13.2.5.80
fn (mut t Tokenizer) do_state_num_char_reference_end() {
	if t.char_ref_code == 0x00 {
		t.parse_error(.null_character_reference)
		t.char_ref_code = 0xfffd
	}

	// extends range of unicode
	if t.char_ref_code > 0x10ffff {
		t.parse_error(.char_reference_outside_unicode_range)
		t.char_ref_code = 0xfffd
	}

	// surrogate
	if t.char_ref_code >= 0xd800 && t.char_ref_code <= 0xdfff {
		t.parse_error(.surrogate_char_reference)
		t.char_ref_code = 0xfffd
	}

	// noncharacter
	if (t.char_ref_code >= 0xfdd0 && t.char_ref_code <= 0xfdef) || t.char_ref_code in [0xfffe, 0xffff, 0x1fffe, 0x1ffff, 0x2fffe, 0x2ffff, 0x3fffe, 0x3ffff, 0x4fffe, 0x4ffff, 0x5fffe, 0x5ffff, 0x6fffe, 0x6ffff, 0x7fffe, 0x7ffff, 0x8fffe, 0x8ffff, 0x9fffe, 0x9ffff, 0xafffe, 0xaffff, 0xbfffe, 0xbffff, 0xcfffe, 0xcffff, 0xdfffe, 0xdffff 0xefffe, 0xeffff, 0xffffe, 0xfffff, 0x10fffe, 0x10ffff] {
		t.parse_error(.noncharacter_char_reference)
	}

	// control
	if t.curr_char !in whitespace && (t.char_ref_code == 0x0d || (t.char_ref_code >= 0x007f && t.char_ref_code <= 0x009f) || (t.char_ref_code >= 0x0000 && t.char_ref_code <= 0x001f)) {
		t.parse_error(.control_char_reference)
		table := {
			0x80: 0x20ac, 0x82: 0x201a, 0x83: 0x0192,
			0x84: 0x201e, 0x85: 0x2026, 0x86: 0x2020,
			0x87: 0x2021, 0x88: 0x02c6, 0x89: 0x2030,
			0x8a: 0x0160, 0x8b: 0x2039, 0x8c: 0x0152,
			0x8e: 0x017d, 0x91: 0x2018, 0x92: 0x2019,
			0x93: 0x201c, 0x94: 0x201d, 0x95: 0x2022,
			0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02dc,
			0x99: 0x2122, 0x9a: 0x0161, 0x9b: 0x203a,
			0x9c: 0x0153, 0x9e: 0x017e, 0x9f: 0x0178
		}
		if t.char_ref_code in table.keys() {
			t.char_ref_code = table[t.char_ref_code]
		}
	}

	t.bldr = strings.new_builder(1)
	t.bldr.write_rune(rune(t.char_ref_code))
	t.flush_codepoints()
	t.do_return_state(false)
}