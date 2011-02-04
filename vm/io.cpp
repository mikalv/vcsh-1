
/* io.cpp
 *
 * The I/O subsystem. This tries to be as R5RS compliant as possible.
 */

#include <ctype.h>
#include <memory.h>
#include <stdio.h>

#include "scan.h"

BEGIN_NAMESPACE(scan)

/*  REVISIT: It'd be nice to have an 'tee' port to write output to multiple destination ports. */

/*  REVISIT: Do we need to restrict bootup NULL I/O */

/*  REVISIT: lots of logic supports default ports if port==NULL. Move to scheme? */

/*** End-of-file object ***/
LRef lmake_eof()
{
     return LREF2_CONS(LREF2_EOF, 0);
}

LRef leof_objectp(LRef obj)
{
     return EOFP(obj) ? obj : boolcons(false);
}

/*** Port object ***/

LRef port_gc_mark(LRef obj)
{
     gc_mark(PORT_PINFO(obj)->_port_name);
     gc_mark(PORT_PINFO(obj)->_user_object);

     for (size_t ii = 0; ii < FAST_LOAD_STACK_DEPTH; ii++)
          gc_mark(PORT_PINFO(obj)->_fasl_stack[ii]);

     gc_mark(PORT_PINFO(obj)->_fasl_accum);

     return PORT_PINFO(obj)->_fasl_table;
}

void port_gc_free(LRef port)
{
     assert(PORTP(port));
     assert(PORT_CLASS(port));

     if (PORT_CLASS(port)->_close)
          PORT_CLASS(port)->_close(port);

     if (PORT_TEXT_INFO(port))
          safe_free(PORT_TEXT_INFO(port));

     if (PORT_CLASS(port)->_gc_free)
          PORT_CLASS(port)->_gc_free(port);

     safe_free(PORT_PINFO(port));
}

LRef initialize_port(LRef s,
                     port_class_t * cls,
                     LRef port_name, port_mode_t mode, LRef user_object, void *user_data)
{
     bool binary = (mode & PORT_BINARY) == PORT_BINARY;

     assert(cls != NULL);
     assert(cls->_valid_modes & mode);
     assert(!NULLP(s));

     SET_PORT_PINFO(s, (port_info_t *) safe_malloc(sizeof(port_info_t)));
     SET_PORT_CLASS(s, cls);

     PORT_PINFO(s)->_port_name = port_name;
     PORT_PINFO(s)->_user_data = user_data;
     PORT_PINFO(s)->_user_object = user_object;
     PORT_PINFO(s)->_fasl_table = NIL;
     PORT_PINFO(s)->_fasl_accum = NIL;
     
     PORT_PINFO(s)->_fasl_stack_ptr = 0;

     for (size_t ii = 0; ii < FAST_LOAD_STACK_DEPTH; ii++)
          PORT_PINFO(s)->_fasl_stack[ii] = NIL;

     PORT_PINFO(s)->_mode = mode;

     PORT_PINFO(s)->_bytes_read = 0;
     PORT_PINFO(s)->_bytes_written = 0;

     if (binary)
     {
          SET_PORT_TEXT_INFO(s, NULL);
     }
     else
     {
          SET_PORT_TEXT_INFO(s,
                             (port_text_translation_info_t *)
                             safe_malloc(sizeof(port_text_translation_info_t)));

          memset(PORT_TEXT_INFO(s)->_unread_buffer, 0, sizeof(PORT_TEXT_INFO(s)->_unread_buffer));
          PORT_TEXT_INFO(s)->_unread_valid = 0;

          sys_info_t sinf;
          sys_get_info(&sinf);

          PORT_TEXT_INFO(s)->_crlf_translate = (sinf._eoln == SYS_EOLN_CRLF);

          PORT_TEXT_INFO(s)->_needs_lf = FALSE;
          PORT_TEXT_INFO(s)->_column = 0;
          PORT_TEXT_INFO(s)->_row = 1;
          PORT_TEXT_INFO(s)->_previous_line_length = 0;
     }


     if (PORT_CLASS(s)->_open)
          PORT_CLASS(s)->_open(s);

     return (s);
}

size_t port_length(LRef port)
{
     assert(PORTP(port));

     if (PORT_CLASS(port)->_length)
          return PORT_CLASS(port)->_length(port);

     return 0;
}

size_t write_raw(const void *buf, size_t size, size_t count, LRef port)
{
     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();

     assert(!NULLP(port));
     assert(PORT_CLASS(port)->_write);

     PORT_PINFO(port)->_bytes_written += (size * count);

     return PORT_CLASS(port)->_write(buf, size, count, port);
}

size_t read_raw(void *buf, size_t size, size_t count, LRef port)
{
     if (NULLP(port))
          port = CURRENT_INPUT_PORT();

     assert(!NULLP(port));
     assert(PORT_CLASS(port)->_read);

     size_t actual_count = PORT_CLASS(port)->_read(buf, size, count, port);

     PORT_PINFO(port)->_bytes_read += (size * actual_count);

     return actual_count;
}

LRef portcons(port_class_t * cls, LRef port_name, port_mode_t mode, LRef user_object,
              void *user_data)
{
     LRef s = new_cell(TC_PORT);

     return initialize_port(s, cls, port_name, mode, user_object, user_data);
}

/***** C I/O functions *****/

int read_char(LRef port)
{
     int ch = EOF;

     if (NULLP(port))
          port = CURRENT_INPUT_PORT();

     assert(!NULLP(port));

     if (!(PORT_MODE(port) & PORT_INPUT))
          return ch;

     /* Read the next character, perhaps from the unread buffer... */
     if (!PORT_BINARYP(port) && (PORT_TEXT_INFO(port)->_unread_valid > 0))
     {
          PORT_TEXT_INFO(port)->_unread_valid--;

          ch = PORT_TEXT_INFO(port)->_unread_buffer[PORT_TEXT_INFO(port)->_unread_valid];
     }
     else
     {
          _TCHAR tch;

          if (read_raw(&tch, sizeof(_TCHAR), 1, port) == 0)
               ch = EOF;
          else
               ch = tch;

          /* ... Text ports get special processing. */
          if (!PORT_BINARYP(port))
          {
               /* _crlf_translate mode forces all input newlines (CR, LF, CR+LF) into LF's. */
               if (PORT_TEXT_INFO(port)->_crlf_translate)
               {
                    if (ch == '\r')
                    {
                         ch = '\n';
                         PORT_TEXT_INFO(port)->_needs_lf = TRUE;
                    }
                    else if (PORT_TEXT_INFO(port)->_needs_lf)
                    {
                         PORT_TEXT_INFO(port)->_needs_lf = FALSE;

                         /*  Notice: this _returns_ from read_char, to avoid double
                          *  counting ch in the position counters. */
                         if (ch == '\n')
                              return read_char(port);
                    }
               }
          }
     }

     if (!PORT_BINARYP(port))
     {
          /* Update the text position indicators */
          if (ch == '\n')
          {
               PORT_TEXT_INFO(port)->_row++;
               PORT_TEXT_INFO(port)->_previous_line_length = PORT_TEXT_INFO(port)->_column;
               PORT_TEXT_INFO(port)->_column = 0;
          }
          else
               PORT_TEXT_INFO(port)->_column++;
     }

     return ch;
}

int unread_char(int ch, LRef port)
{
     if (NULLP(port))
          port = CURRENT_INPUT_PORT();

     assert(!NULLP(port));

     if (PORT_BINARYP(port))
          vmerror_unsupported(_T("cannot unread on binary ports."));

     switch (ch)
     {
     case '\n':
          PORT_TEXT_INFO(port)->_row--;
          PORT_TEXT_INFO(port)->_column = PORT_TEXT_INFO(port)->_previous_line_length;
          break;

     case '\r':
          break;

     default:
          PORT_TEXT_INFO(port)->_column--;
          break;
     }

     if (PORT_TEXT_INFO(port)->_unread_valid >= PORT_UNGET_BUFFER_SIZE)
          vmerror_io_error(_T("unget buffer exceeded."), port);

     PORT_TEXT_INFO(port)->_unread_buffer[PORT_TEXT_INFO(port)->_unread_valid] = ch;
     PORT_TEXT_INFO(port)->_unread_valid++;

     return ch;
}

int peek_char(LRef port)
{
     int ch = EOF;

     if (NULLP(port))
          port = CURRENT_INPUT_PORT();

     assert(!NULLP(port));

     ch = read_char(port);
     unread_char(ch, port);

     return ch;
}

void write_char(int ch, LRef port)
{
     _TCHAR tch = (_TCHAR) ch;

     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();

     assert(!NULLP(port));

     write_text(&tch, 1, port);

     if (!PORT_BINARYP(port) && (tch == _T('\n')))
          lflush_port(port);
}

size_t write_text(const _TCHAR * buf, size_t count, LRef port)
{
     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();

     assert(PORTP(port));

     if ((PORT_PINFO(port)->_mode & PORT_OUTPUT) != PORT_OUTPUT)
          return 0;

     if (PORT_BINARYP(port))
     {
          return write_raw(buf, sizeof(_TCHAR), count, port);
     }
     else if (!PORT_TEXT_INFO(port)->_crlf_translate)
     {
          for (size_t ii = 0; ii < count; ii++)
          {
               if (buf[ii] == _T('\n'))
               {
                    PORT_TEXT_INFO(port)->_row++;
                    PORT_TEXT_INFO(port)->_column = 0;
               }
               else
                    PORT_TEXT_INFO(port)->_column++;
          }

          return write_raw(buf, sizeof(_TCHAR), count, port);
     }
     else
     {
          /* This code divides the text to be written into blocks seperated
           * by line seperators. raw_write is called for each block to
           * actually do the write, and line seperators are correctly
           * translated to CR+LF pairs. */

          for (size_t next_char_to_write = 0; next_char_to_write < count;)
          {
               unsigned int c = _T('\0');
               size_t next_eoln_char;

               /* Scan for the next eoln character, it ends the block... */
               for (next_eoln_char = next_char_to_write; (next_eoln_char < count); next_eoln_char++)
               {
                    c = buf[next_eoln_char];

                    if ((c == '\n') || (c == '\r') || PORT_TEXT_INFO(port)->_needs_lf)
                         break;
               }

               if (PORT_TEXT_INFO(port)->_needs_lf)
               {
                    assert(next_eoln_char - next_char_to_write == 0);

                    if (buf[next_eoln_char] == _T('\n'))
                         next_eoln_char++;

                    write_raw(_T("\n"), sizeof(_TCHAR), 1, port);

                    PORT_TEXT_INFO(port)->_needs_lf = false;
                    PORT_TEXT_INFO(port)->_row++;
               }
               else if (next_eoln_char - next_char_to_write == 0)
               {
                    switch (c)
                    {
                    case _T('\n'):
                         write_raw(_T("\r\n"), sizeof(_TCHAR), 2, port);
                         PORT_TEXT_INFO(port)->_column = 0;
                         PORT_TEXT_INFO(port)->_row++;
                         break;

                    case _T('\r'):
                         write_raw(_T("\r"), sizeof(_TCHAR), 1, port);
                         PORT_TEXT_INFO(port)->_column = 0;
                         PORT_TEXT_INFO(port)->_needs_lf = true;
                         break;

                    default:
                         panic("Invalid case in write_text");
                    }

                    next_eoln_char++;
               }
               else
               {
                    PORT_TEXT_INFO(port)->_column += (next_eoln_char - next_char_to_write);
                    write_raw(&(buf[next_char_to_write]), sizeof(_TCHAR),
                              next_eoln_char - next_char_to_write, port);
               }

               next_char_to_write = next_eoln_char;
          }
     }

     return count;
}

static int flush_whitespace(LRef port, bool skip_lisp_comments = true)
{
     int c = '\0';

     bool commentp = false;
     bool reading_whitespace = true;

     while (reading_whitespace)
     {
          /*  We can never be in a comment if we're not skipping them... */
          assert(skip_lisp_comments ? true : !commentp);

          c = read_char(port);

          if (c == EOF)
               break;
          else if (commentp)
          {
               if (c == _T('\n'))
                    commentp = FALSE;
          }
          else if ((c == _T(';')) && skip_lisp_comments)
          {
               commentp = TRUE;
          }
          else if (!_istspace(c) && (c != _T('\0')))
               break;
     }

     if (c != EOF)
          unread_char(c, port);

     return c;
}

bool read_binary_fixnum(fixnum_t length, bool signedp, LRef port, fixnum_t & result)
{
#ifdef FIXNUM_64BIT
     assert((length == 1) || (length == 2) || (length == 4) || (length == 8));
#else
     assert((length == 1) || (length == 2) || (length == 4));
#endif

     assert(PORTP(port));
     assert(PORT_BINARYP(port));

     u8_t bytes[sizeof(fixnum_t)];
     size_t fixnums_read = read_raw(bytes, (size_t) length, 1, port);

     if (!fixnums_read)
          return false;


     switch (length)
     {
     case 1:
          result = (signedp ? (fixnum_t) (*(i8_t *) bytes) : (fixnum_t) (*(u8_t *) bytes));
          break;
     case 2:
          result = (signedp ? (fixnum_t) (*(i16_t *) bytes) : (fixnum_t) (*(u16_t *) bytes));
          break;
     case 4:
          result = (signedp ? (fixnum_t) (*(i32_t *) bytes) : (fixnum_t) (*(u32_t *) bytes));
          break;
#ifdef FIXNUM_64BIT
     case 8:
          result = (signedp ? (fixnum_t) (*(i64_t *) bytes) : (fixnum_t) (*(u64_t *) bytes));
          break;
#endif
     }

     return true;
}


bool read_binary_flonum(LRef port, flonum_t & result)
{
     assert(PORTP(port));
     assert(PORT_BINARYP(port));

     u8_t bytes[sizeof(flonum_t)];
     size_t flonums_read = read_raw(bytes, sizeof(flonum_t), 1, port);

     if (!flonums_read)
          return false;

     result = *(flonum_t *) bytes;

     return true;
}


/***** Lisp-visible port functions *****/

LRef linput_portp(LRef obj)
{
     if (PORTP(obj) && (PORT_MODE(obj) & PORT_INPUT))
          return obj;
     else
          return boolcons(false);
}

LRef loutput_portp(LRef obj)
{
     if (PORTP(obj) && (PORT_MODE(obj) & PORT_OUTPUT))
          return obj;
     else
          return boolcons(false);
}

LRef lbinary_portp(LRef obj)
{
     if (PORTP(obj) && (PORT_BINARYP(obj)))
          return obj;
     else
          return boolcons(false);
}

LRef lport_mode(LRef obj)
{
     if (!PORTP(obj))
          vmerror_wrong_type(1, obj);

     switch (PORT_MODE(obj) & PORT_DIRECTION)
     {
     case PORT_CLOSED:
          return keyword_intern(_T("closed"));
     case PORT_INPUT:
          return keyword_intern(_T("input"));
     case PORT_OUTPUT:
          return keyword_intern(_T("output"));
     case PORT_INPUT_OUTPUT:
          return keyword_intern(_T("input/output"));
     }

     panic(_T("corrupt port"));

     return NIL;
}


LRef lport_name(LRef port)
{
     if (NULLP(port))
          port = CURRENT_INPUT_PORT();

     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     return PORT_PINFO(port)->_port_name;
}

LRef lport_location(LRef port)
{
     if (NULLP(port))
          port = CURRENT_INPUT_PORT();

     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     if (PORT_BINARYP(port))
          return fixcons(PORT_PINFO(port)->_bytes_read);
     else
          return lcons(fixcons(PORT_TEXT_INFO(port)->_row), fixcons(PORT_TEXT_INFO(port)->_column));
}

LRef lport_translate_mode(LRef port)
{
     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     if (PORT_BINARYP(port))
          return boolcons(false);
     else
          return boolcons(PORT_TEXT_INFO(port)->_crlf_translate);
}

LRef lport_set_translate_mode(LRef port, LRef mode)
{
     if (!PORTP(port))
          vmerror_wrong_type(1, port);
     if (!BOOLP(mode))
          vmerror_wrong_type(2, mode);

     if (PORT_BINARYP(port))
          vmerror_unsupported(_T("cannot set translation mode of binary ports"));

     lflush_port(port);

     bool old_translate_mode = PORT_TEXT_INFO(port)->_crlf_translate;

     PORT_TEXT_INFO(port)->_crlf_translate = TRUEP(mode);

     return boolcons(old_translate_mode);
}

LRef lport_io_counts(LRef port)
{
     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     return lcons(fixcons(PORT_PINFO(port)->_bytes_read),
                  fixcons(PORT_PINFO(port)->_bytes_written));
}

LRef lclose_port(LRef port)
{
     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     if (PORT_PINFO(port)->_mode & PORT_OUTPUT)
          lflush_port(port);

     if (PORT_CLASS(port)->_close)
          PORT_CLASS(port)->_close(port);

     PORT_PINFO(port)->_mode = PORT_CLOSED;

     return port;
}

LRef lflush_port(LRef port)
{
     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     if ((!PORT_BINARYP(port))
         && (PORT_TEXT_INFO(port)->_crlf_translate) && (PORT_TEXT_INFO(port)->_needs_lf))
     {
          write_char(_T('\n'), port);
     }

     if (PORT_CLASS(port)->_flush)
          PORT_CLASS(port)->_flush(port);

     return port;
}



LRef lread_char(LRef port)
{
     if (NULLP(port))
          port = CURRENT_INPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(1, port);

     assert(PORTP(port));

     int ch = read_char(port);

     if (ch == EOF)
          return lmake_eof();
     else
          return charcons((_TCHAR) ch);
}

LRef lunread_char(LRef ch, LRef port)
{
     if (NULLP(port))
          port = CURRENT_INPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(1, port);

     if (!CHARP(ch))
          vmerror_wrong_type(2, ch);

     assert(PORTP(port));

     unread_char(CHARV(ch), port);

     return port;
}


LRef lpeek_char(LRef port)
{
     int ch;

     if (NULLP(port))
          port = CURRENT_INPUT_PORT();

     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     ch = peek_char(port);

     if (ch == EOF)
          return lmake_eof();
     else
          return charcons((_TCHAR) ch);
}

LRef lwrite_char(LRef ch, LRef port)
{
     if (!CHARP(ch))
          vmerror_wrong_type(1, ch);

     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();

     if (!PORTP(port))
          vmerror_wrong_type(2, port);

     write_char(CHARV(ch), port);

     return port;
}


LRef lwrite_strings(size_t argc, LRef argv[])
{
     LRef port = (argc < 1) ? NIL : argv[0];

     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     for (size_t ii = 1; ii < argc; ii++)
     {
          LRef str = argv[ii];

          if (STRINGP(str))
               write_text(STRING_DATA(str), STRING_DIM(str), port);
          else if (CHARP(str))
          {
               _TCHAR ch = CHARV(str);

               write_text(&ch, 1, port);
          }
          else
               vmerror_wrong_type(ii, str);
     }

     return port;
}


LRef lchar_readyp(LRef port)
{
     if (NULLP(port))
          port = CURRENT_INPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(1, port);

     if (PORT_CLASS(port)->_read_readyp)
          return boolcons(PORT_CLASS(port)->_read_readyp(port));
     else
     {
          /*  If there's not explicit char-ready? handling provided by the port,
           *  we use this hokey logic that defaults to true unless the port
           *  is at EOF. Because our EOF detection depends on peek_char, we
           *  can't even go that far with binary ports. Fixing this will require
           *  bypassing the C RTL I/O logic, which will have to wait. */

          if (PORT_BINARYP(port))
               vmerror_unsupported(_T("char-ready? not supported on binary ports"));

          return boolcons(peek_char(port) != EOF);
     }
}


LRef lflush_whitespace(LRef port, LRef slc)
{
     int ch = EOF;

     if (NULLP(port))
          port = CURRENT_INPUT_PORT();

     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     bool skip_lisp_comments = true;

     if (!NULLP(slc))
     {
          if (!BOOLP(slc))
               vmerror_wrong_type(2, slc);

          skip_lisp_comments = BOOLV(slc);
     }


     assert(!NULLP(port));

     if (PORT_MODE(port) & PORT_INPUT)
          ch = flush_whitespace(port, skip_lisp_comments);

     if (ch == EOF)
          return lmake_eof();
     else
          return charcons((_TCHAR) ch);
}


LRef lread_binary_string(LRef l, LRef port)
{
     _TCHAR buf[STACK_STRBUF_LEN];

     if (NULLP(port))
          port = CURRENT_INPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(2, port);

     assert(PORTP(port));

     if (!PORT_BINARYP(port))
          vmerror_unsupported(_T("raw port operations not supported on text ports"));

     if (!NUMBERP(l))
          vmerror_wrong_type(1, l);

     fixnum_t remaining_length = get_c_fixnum(l);

     if (remaining_length <= 0)
          vmerror_arg_out_of_range(l, _T(">0"));

     LRef new_str = strcons();
     size_t total_read = 0;

     while (remaining_length > 0)
     {
          fixnum_t to_read = remaining_length;

          if (to_read > STACK_STRBUF_LEN)
               to_read = STACK_STRBUF_LEN;

          size_t actual_read = read_raw(buf, sizeof(_TCHAR), (size_t) remaining_length, port);

          if (actual_read <= 0)
               break;

          str_append_str(new_str, buf, actual_read);

          remaining_length -= actual_read;
          total_read += actual_read;
     }

     if (total_read == 0)
          return lmake_eof();

     return new_str;
}


LRef lread_binary_fixnum(LRef l, LRef sp, LRef port)
{
     if (NULLP(port))
          port = CURRENT_INPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(3, port);

     if (!PORT_BINARYP(port))
          vmerror_unsupported(_T("raw port operations not supported on text ports"));

     if (!NUMBERP(l))
          vmerror_wrong_type(1, l);
     if (!BOOLP(sp))
          vmerror_wrong_type(2, sp);

     fixnum_t length = get_c_fixnum(l);
     bool signedp = BOOLV(sp);

#ifdef FIXNUM_64BIT
     if ((length != 1) && (length != 2) && (length != 4) && (length != 8))
          vmerror_arg_out_of_range(l, _T("1, 2, 4, or 8"));
#else
     if ((length != 1) && (length != 2) && (length != 4))
          vmerror_arg_out_of_range(l, _T("1, 2, or 4"));
#endif

     fixnum_t result = 0;

     if (read_binary_fixnum(length, signedp, port, result))
          return fixcons(result);
     else
          return lmake_eof();
}

LRef lread_binary_flonum(LRef port)
{
     if (NULLP(port))
          port = CURRENT_INPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(3, port);

     if (!PORT_BINARYP(port))
          vmerror_unsupported(_T("raw port operations not supported on text ports"));

     flonum_t result = 0;

     if (read_binary_flonum(port, result))
          return flocons(result);
     else
          return lmake_eof();
}

LRef lread_line(LRef port)
{
     int ch;

     if (NULLP(port))
          port = CURRENT_INPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(1, port);

     assert(PORTP(port));

     LRef op = lopen_output_string();

     bool read_anything = false;

     for (ch = read_char(port); (ch != EOF) && (ch != _T('\n')); ch = read_char(port))
     {
          read_anything = true;

          write_char(ch, op);
     }

     if (!read_anything && (ch == EOF))
          return lmake_eof();

     return lget_output_string(op);
}

LRef lwrite_binary_string(LRef string, LRef port)
{
     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(2, port);

     assert(PORTP(port));

     if (!PORT_BINARYP(port))
          vmerror_unsupported(_T("raw port operations not supported on text ports"));

     if (!STRINGP(string))
          vmerror_wrong_type(1, string);

     size_t length = STRING_DIM(string);
     _TCHAR *strdata = STRING_DATA(string);

     size_t chars_written = write_raw(strdata, sizeof(_TCHAR), length, port);

     if (chars_written < length)
          vmerror_io_error(_T("error writing to port."), port);

     return fixcons(chars_written);
}

LRef lwrite_binary_fixnum(LRef v, LRef l, LRef sp, LRef port)
{
     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(4, port);

     assert(PORTP(port));

     if (!PORT_BINARYP(port))
          vmerror_unsupported(_T("raw port operations not supported on text ports"));

     if (!FIXNUMP(v))
          vmerror_wrong_type(1, v);

     if (!NUMBERP(l))
          vmerror_wrong_type(2, l);

     if (!BOOLP(sp))
          vmerror_wrong_type(3, sp);

     fixnum_t length = get_c_fixnum(l);
     bool signedp = BOOLV(sp);

#ifdef FIXNUM_64BIT
     if ((length != 1) && (length != 2) && (length != 4) && (length != 8))
          vmerror_arg_out_of_range(l, _T("1, 2, 4, or 8"));
#else
     if ((length != 1) && (length != 2) && (length != 4))
          vmerror_arg_out_of_range(l, _T("1, 2, or 4"));
#endif

     fixnum_t val = FIXNM(v);

     u8_t bytes[sizeof(fixnum_t)];

     switch (length)
     {
     case 1:
          if (signedp)
               *(i8_t *) bytes = (i8_t) val;
          else
               *(u8_t *) bytes = (u8_t) val;
          break;

     case 2:
          if (signedp)
               *(i16_t *) bytes = (i16_t) val;
          else
               *(u16_t *) bytes = (u16_t) val;
          break;

     case 4:
          if (signedp)
               *(i32_t *) bytes = (i32_t) val;
          else
               *(u32_t *) bytes = (u32_t) val;
          break;

#ifdef FIXNUM_64BIT
     case 8:
          if (signedp)
               *(i64_t *) bytes = (i64_t) val;
          else
               *(u64_t *) bytes = (u64_t) val;
          break;
#endif
     }

     size_t fixnums_written = write_raw(bytes, (size_t) length, 1, port);

     if (fixnums_written < 1)
          vmerror_io_error(_T("error writing to port."), port);

     return fixcons(fixnums_written);
}

LRef lbinary_write_flonum(LRef v, LRef port)
{
     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();
     else if (!PORTP(port))
          vmerror_wrong_type(4, port);

     assert(PORTP(port));

     if (!PORT_BINARYP(port))
          vmerror_unsupported(_T("raw port operations not supported on text ports"));

     if (!NUMBERP(v))
          vmerror_wrong_type(1, v);

     flonum_t val = get_c_double(v);

     u8_t bytes[sizeof(flonum_t)];

     *(flonum_t *) bytes = val;

     size_t flonums_written = write_raw(bytes, sizeof(flonum_t), 1, port);

     if (flonums_written < 1)
          vmerror_io_error(_T("error writing to port."), port);

     return fixcons(flonums_written);
}


LRef lrich_write(LRef obj, LRef machine_readable, LRef port)
{
     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();

     if (!PORTP(port))
          vmerror_wrong_type(3, port);

     if (PORT_CLASS(port)->_rich_write == NULL)
          return boolcons(false);

     if (PORT_CLASS(port)->_rich_write(obj, TRUEP(machine_readable), port))
          return port;

     return boolcons(false);
}


LRef lnewline(LRef port)
{
     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();

     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     write_char(_T('\n'), port);

     return port;
}

LRef lfresh_line(LRef port)
{
     if (NULLP(port))
          port = CURRENT_OUTPUT_PORT();

     if (!PORTP(port))
          vmerror_wrong_type(1, port);

     if (PORT_BINARYP(port)
         || ((PORT_TEXT_INFO(port)->_column != 0) && !PORT_TEXT_INFO(port)->_needs_lf))
     {
          lnewline(port);
          return boolcons(true);
     }

     return boolcons(false);
}

/* Null port
 *
 * Input port - Always reads out EOF.
 * Output port - Accepts all writes.
 */

size_t null_port_read(void *buf, size_t size, size_t count, LRef obj)
{
     UNREFERENCED(buf);
     UNREFERENCED(size);
     UNREFERENCED(count);
     UNREFERENCED(obj);

     return 0;
}

size_t null_port_write(const void *buf, size_t size, size_t count, LRef obj)
{
     UNREFERENCED(buf);
     UNREFERENCED(size);
     UNREFERENCED(obj);

     return count;
}

port_class_t null_port_class = {
     _T("NULL"),
     PORT_INPUT_OUTPUT,

     NULL,

     NULL,
     null_port_read,
     null_port_write,
     NULL,

     NULL,
     NULL,
     NULL,

     NULL,
};


LRef lopen_null_port()
{
     return portcons(&null_port_class, NIL, (port_mode_t) (PORT_INPUT_OUTPUT | PORT_BINARY),
                     NIL, NULL);
}


END_NAMESPACE
