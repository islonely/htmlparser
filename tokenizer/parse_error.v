module tokenizer

// end of file errors
const (
	eof_generic_name    = 'EOF'
	eof_generic_msg     = 'The end of the file has been reached.'
	eof_in_doctype_name = 'EOF in doctype.'
	eof_in_doctype_msg  = 'This error occurs if the parser encounter the end of the input stream in a DOCTYPE. In such a case, if the DOCTYPE is correctly placed as a document preamble, the parser sets the Document to quirks mode.'
	eof_before_tag_name_name = 'EOF before tag name.'
	eof_before_tag_name_msg  = 'This error occurs if the parser encounters the end of the input stream where a tag name is expected. In this case the parser treats the beginning of a start tag (i.e., `<`) or an end tag (i.e., `</`) as text content.'
	eof_in_tag_name = 'EOF in tag.'
	eof_in_tag_msg  = 'This error occurs if the parser encounters the end of the input stream in a start tag or an end tag (e.g., `<div id=`). Such a tag is ignored.'
	eof_in_script_html_comment_like_text_name = 'EOF in script HTML comment like text.'
	eof_in_script_html_comment_like_text_msg  = 'This error occurs if the parser encounters the end of the input stream in text that resembles an HTML comment inside `script` element content (e.g., `<script><!-- foo`).'
	eof_in_cdata_name = 'EOF in CDATA.'
	eof_in_cdata_msg  = 'This error occurs if the parser encounters the end of the input stream in a CDATA section. The parser treats such CDATA sections as if they are closed immediately before the end of the input stream.'
	eof_in_comment_name = 'EOF in comment.'
	eof_in_comment_msg = 'This error occurs if the parser ecounters the end of the input stream in a comment. The parser treats such comments as if they are closed immediately before the end of the input stream.'
)

enum ParseError {
	unexpected_null_character
	unexpected_char_after_doctype_system_identifier
	unexpected_char_in_attr_name
	unexpected_char_in_unquoted_attr_value
	unexpected_equals_sign_before_attr_name
	unexpected_question_mark_instead_of_tag_name
	unexpected_solidus_in_tag
	unknown_named_char_reference
	missing_quote_before_doctype_public_identifier
	missing_quote_before_doctype_system_identifier
	missing_whitespace_before_doctype_name
	missing_attr_value
	missing_doctype_name
	missing_doctype_public_identifier
	missing_doctype_system_identifier
	missing_end_tag_name
	missing_semicolon_after_char_reference
	missing_whitespace_after_doctype_public_keyword
	missing_whitespace_after_doctype_system_keyword
	missing_whitespace_between_attr
	missing_whitespace_between_doctype_public_and_system_identifiers
	nested_comment
	noncharacter_char_reference
	null_character_reference
	abrupt_closing_of_empty_comment
	abrupt_doctype_public_identifier
	abrupt_doctype_system_identifier
	absence_of_digits_in_num_char_reference
	cdata_in_html_content
	char_reference_outside_unicode_range
	control_char_reference
	duplicate_attr
	eof_before_tag_name
	eof_in_cdata
	eof_in_comment
	eof_in_doctype
	eof_in_script_html_comment_like_text
	eof_in_tag
	incorrectly_closed_comment
	incorrectly_opened_comment
	invalid_char_sequence_after_doctype_name
	invalid_first_character_of_tag_name
	surrogate_char_reference
}
