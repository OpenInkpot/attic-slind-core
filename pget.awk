#!/usr/bin/nawk -f
#--------------------------------------------------------------------
# @(#) pget.awk - generic parameter extraction engine
#--------------------------------------------------------------------
# $Id: pget.awk,v 1.40 2007/08/06 15:39:14 david4 Exp $
#
# NAME
#   pget.awk - generic parameter extraction engine
#
# LICENSE
#   Copyright (C) 2002-2006 David Thompson
# 
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
# 
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  For more
#   details, see the GNU General Public License at,
#
#       http://www.gnu.org/licenses/gpl.html
#
# AUTHOR
#   Send all enhancements and bug reports to David Thompson at
#   datNO1965S@yahPoo.cAMom.
#
# SYNOPSIS
#   pget.awk [SECTION=section] [PARAM=name]
#            [DEBLANK=1] [TRIM=1] [JOIN={1|c}] [JOINC={1|c}]
#            [TEST={n|z}] [KEEPHASH=1] [PRINT={0|1|2|3|4}]
#            [GETENV=1] [DEFAULT=x] [DEBUG=1] [file...]
#
# DESCRIPTION
#   pget.awk is a parameter extraction engine for initialization files,
#   which are text files containing parameter definitions.  A parameter
#   definition is a name and value pair separated by an '=' character.
#
#   Example parameter definitions,
#
#       PATH=/usr/bin:/bin
#       MANPATH=/usr/share/man:/usr/local/man
#       PAGER=more
#
#   Note that the Unix shell environment can be viewed as sequence of
#   parameter definitions.
#
#   To print the value of your Unix PATH, try this,
#
#       env | pget.awk PARAM=PATH
#
#   Given the parameter name using "PARAM=name", pget.awk outputs the
#   value of parameter "name".  If name is not found, pget.awk prints
#   the DEFAULT value (if DEFAULT is defined), otherwise no output is
#   produced.
#
#   pget.awk fully understands input files without section headers.
#   For example, the output of the Unix env command is valid input to
#   pget.awk.  Multiple input files are treated as if they were con-
#   catenated together.
#
#   pget.awk fully understands how to properly ignore comments.  Input
#   lines starting with ';' or '#' as the first non-white character are
#   comment lines.  Input lines with '#' appearing after the '=' are the
#   start of a trailing comment.  See COMMENT PROCESSING below.
#
#   Whitespace in parameter definitions is (mostly) insignificant.
#   The examples above could have been formatted like,
#
#       PATH    = /usr/bin:/bin
#       MANPATH    =  /usr/share/man:/usr/local/man
#          PAGER =more
#
#   Specifically, whitespace before and after the '=' is ignored, as well
#   as leading and trailing whitespace before and after the parameter
#   definition (before the name and after the value).
#
#   pget.awk fully supports traditional Microsoft Windows ini files.
#   The Microsoft Windows ini file format invented section headers
#   as organizational checkpoints to group parameter definitions into
#   an addressable subfile of the input.
#
#   In pget.awk, a section header begins with the '[' character in column
#   one, continues with the section header name, and closes with the ']'
#   character as the last nonwhite character on the line.  All whitespace
#   inside the '[' and ']' is significant.  Specify the section header
#   name using "SECTION=section".  Note that if SECTION is undefined, the
#   implied section is used.
#
#   pget.awk defines the "implied" section to refer to that portion of the
#   initialization file before the start of the first section header.  From
#   pget.awk's point of view, all files have an implied section, even if it
#   is empty.  Traditional Microsoft Windows ini files did not have
#   implied sections.
#
#   Note that the input file may have no section headers, in which case all
#   parameter definitions are part of the implied section.  With pget.awk,
#   it is extremely convenient to reserve the implied section for general
#   parameters, using a section header only when the parameter needs to be
#   identified with a specific purpose.  For example, this input,
#
#       PAGER=more
#       [daisy may]
#       PAGER = less
#       [billy bob]
#       PAGER = less -k
#
#   defines 3 different parameters in 3 sections (the implied section plus
#   2 others).  Each of these parameters may be accessed with pget.awk,
#
#       pget.awk PARAM=PAGER
#       pget.awk SECTION="daisy may" PARAM=PAGER
#       pget.awk SECTION="billy bob" PARAM=PAGER
#
#   pget.awk treats parameters of the same name in different sections as
#   different, but parameters of the same name in the same section are the
#   same.  For example, this input,
#
#       [boot]
#       file = vxd.dll
#       file = kbd.dll
#       file =
#       file = vio.dll
#
#   with this command,
#
#       pget.awk SECTION=boot PARAM=file
#
#   generates this output,
#
#       vxd.dll
#       kbd.dll
#       vio.dll
#
#   pget.awk also supports continuation lines.  The above input could have
#   been written as,
#
#       [boot]
#       file = vxd.dll \
#       kbd.dll \
#       vio.dll
#
#   or
#
#       [boot]
#       file = \
#       vxd.dll \
#       kbd.dll \
#       vio.dll
#
#   Blank lines continued are preserved.  For example, this input,
#
#       [lincoln]
#       TEXT = Four score and seven years ago, \
#       \
#       our forefathers ...
#
#   with this command,
# 
#       pget.awk SECTION=lincoln PARAM=TEXT
#
#   will produce this output (with the blank line).
#
#       Four score and seven years ago,
#
#       our forefathers ...
#
#   as you would expect.  Specify DEBLANK=1 to remove blank lines continued,
#   see below.
#
#   Note that pget.awk makes no requirement that a section actually contain
#   parameter definitions.  That is, section contents may contain any kind
#   of text data.  For example, this input,
#
#       [boot]
#       vxd.dll
#       kbd.dll
#       vio.dll
#
#   with this command,
#
#       pget.awk SECTION=boot
#
#   generates this output,
#
#       vxd.dll
#       kbd.dll
#       vio.dll
#
#   Use JOIN=1 to combine multi-line output into a single line.  Using the
#   previous input,
#
#       pget.awk SECTION=boot JOIN=1
#
#   generates this output,
#
#       vxd.dll kbd.dll vio.dll
#
#   The default join delimiter is a single space, but it may be any string
#   assigned to the JOIN variable.  For example,
#
#   use JOIN=", " to generate this output,
#
#       vxd.dll, kbd.dll, vio.dll
#
#   use JOIN=":" to generate this output,
#
#       vxd.dll:kbd.dll:vio.dll
#
#   In contrast to JOIN, use JOINC=1 to combine parameter definitions
#   which were continued onto multiple lines.  For example, this input,
#
#       [file]
#       src = vxd.c \
#       kbd.c \
#       vio.c
#       dll = vxd.dll \
#       kbd.dll \
#       vio.dll
#
#   with this command,
#
#       pget.awk SECTION=file PARAM=src JOINC=1
#
#   will produce this output,
#
#       vxd.c kbd.c vio.c
#
#   The differences between JOIN and JOINC are apparent when pget.awk
#   selects multiple parameters.  Since PARAM is a regular expression,
#   this command,
#
#       pget.awk SECTION=file PARAM='(src|dll)' JOINC=1 PRINT=2
#
#   generates this output,
#
#       src = vxd.c kbd.c vio.c
#       dll = vxd.dll kbd.dll vio.dll
#
#   JOINC=":" is also useful,
#
#       src = vxd.c:kbd.c:vio.c
#       dll = vxd.dll:kbd.dll:vio.dll
#
# COMMENT PROCESSING
#   pget.awk recognizes line comments when ';' or '#' appear as the first
#   non-white character on the line.  Trailing comments are only recognized
#   for the '#' character.
#
#   pget.awk follows these rules for comment processing,
#
#       1. If the line matches /^[ \r\t]*;/, it is a line comment and it
#          is always removed.  That is, the main parameter extraction code
#          in the END block never sees these lines.
#
#       2. If the line matches /^[ \r\t]*#/, it is a line comment that
#          receives special handling,
#
#           a. If the line is a continuation line, it is always kept.
#           b. If KEEPHASH=1 was specified, it is kept.
#           c. Otherwise, the line is removed and the END block
#              never sees it.
#
#       3. When a parameter value is about to be printed, any trailing
#          comments starting with '#' are removed.
#
#   pget.awk always removes line comments beginning with ';' and (by
#   default) will remove '#' line comments as well.  However, you may
#   want to keep line comments starting with '#' in the output.  For
#   example, (because pget.awk supports section contents with any kind
#   of text) the following section defines a shell script, using the
#   ubiquitous hash bang as its first line,
#
#       [shell script]
#       #!/bin/sh
#       echo hello world
#
#   pget.awk would normally remove the hash bang line because it sees this
#   line as a comment.  Obviously, this line is not a comment intended for
#   pget.awk but for the shell script itself.
#
#   Therefore, pget.awk supports special processing for all line comments
#   that begin with '#'.  The purpose of KEEPHASH=1 is to retain all '#'
#   line comments in the output.
#
#   Trailing comments begin with the first '#' found after the '=' in
#   parameter definitions.  Whenever pget.awk needs to output the value
#   of a parameter, trailing comments are first removed from the value.
#   Any whitespace appearing before the '#' comment character is also
#   removed.
#
# COMMAND LINE OPTIONS
#   SECTION={reg-exp|string}
#   PARAM={reg-exp|string}
#   In actuality, the SECTION and PARAM variables are always treat as
#   regular expressions.  Either one or both may be undefined.  If SECTION
#   is undefined, then the implied section is used.  If PARAM is undefined,
#   then pget.awk outputs the entire contents of matching SECTIONs.  See
#   this chart below,
#
#   -- Defined? --
#   SECTION  PARAM   then pget.awk output is...
#     Yes     Yes    values matching PARAM in SECTION
#     No      Yes    values matching PARAM in implied section
#     Yes     No     contents of matching SECTION
#     No      No     contents of implied section
#
#   This chart is a subset of a much larger chart.  See PRINT below.
#
#   DEBLANK={0|1}
#   If PARAM is undefined, then pget.awk prints the entire section contents,
#   including all blank lines.  Specify DEBLANK=1 to suppress these blank
#   lines.
#
#   TRIM={0|1}
#   If PARAM is undefined, then pget.awk prints the entire section contents,
#   including all leading and trailing whitespace.  Specify TRIM=1 to strip
#   this leading and trailing whitespace.
#
#   JOIN={0|1|c}
#   A multi-line parameter definition (using continuation character '\')
#   results in multi-line output.  Also, if PARAM is undefined, pget.awk
#   prints the entire section contents, which may also result in multi-line
#   output.  Specify JOIN=1 to concatenate all multi-line output into a
#   single output line.  By default, JOIN=1 will separate concatenated
#   lines with a space.  You can alter this join delimiter using JOIN=c,
#   where c is any character or string.  Ie, JOIN=: and JOIN=", " may be
#   useful.  Note that specifying JOIN={1|c} will automatically define
#   DEBLANK=1 and TRIM=1.
#
#   JOINC={0|1|c}
#   When printing multiple parameter definitions, use JOINC=1 to force
#   pget.awk to correctly join continuation lines together.  That is,
#   multi-line parameters which have been continued using the continuation
#   character '\' will be concatenated correctly in the output, such that
#   the definition for that parameter appears entirely on one line.
#
#   Use JOINC to process continuation lines for parameters only.  JOINC
#   processing occurs first, before JOIN processing.  Note that JOINC
#   handles the joining of output lines for multiple parameters correctly,
#   whereas JOIN has a similar purpose but joins all output into one line.
#
#   TEST={z|n}
#   If TEST=z or TEST=n is defined, pget.awk sets the exit status similar
#   to the Unix test command, and no output is produced.  TEST=z causes
#   pget.awk exit status 0 if the output is length zero, while TEST=n causes
#   pget.awk exit status 0 if the output is non-zero length.  Otherwise,
#   pget.awk exit status is 1.  Note how the 'z' and 'n' processing emulates
#   the -z and -n options of the Unix test command.  Note that the value of
#   DEFAULT does not affect the results of TEST.
#
#   KEEPHASH={0|1}
#   pget.awk supports special processing for line comments starting with
#   the '#' character in column 1.  All line comments starting with ';' are
#   always removed.  However, line comments starting with '#' are always
#   kept for continuation lines (so use ';' to comment out a continuation
#   line), otherwise pget.awk consults the KEEPHASH setting.  Thus, since
#   KEEPHASH=0 is the default setting, line comments starting with '#' are
#   removed by default.  To keep comment lines starting with '#' in the
#   output, use KEEPHASH=1.
#
#   PRINT={0|1|2|3|4}
#   The default value PRINT=0 produces default output, it does *not*
#   disable output.  Consult the table below,
#
#   ------ Defined? -----
#   SECTION  PARAM  PRINT then pget.awk output is...
#     Yes     Yes     0   values matching PARAM in SECTION [1]
#     Yes     Yes     1   names matching PARAM in SECTION
#     Yes     Yes     2   definitions matching PARAM in SECTION
#     No      Yes     0   values matching PARAM in implied section [1]
#     No      Yes     1   names matching PARAM in implied section
#     No      Yes     2   definitions matching PARAM in implied section
#     Yes     No      0   contents of matching SECTION [1]
#     Yes     No      1   section headers matching SECTION
#     Yes     No      2   header+content of sections matching SECTION
#     No      No      0   contents of implied section [1] [2]
#     No      No      1   all parameter names of implied section
#     No      No      2   all parameter definitions of implied section [2]
#
#   [1] When PRINT is not defined, PRINT=0 is assumed.
#
#   [2] When both SECTION and PARAM are undefined, PRINT=0 and PRINT=2
#       produce the same output, except that PRINT=2 omits blank lines.
#
#   Use PRINT=3 to print parameter definitions suitable for input to a
#   POSIX shell.  Use PRINT=4 to print each definition with an export
#   statement attached.  Note that PRINT=3 and PRINT=4 should be viewed
#   as experimental extensions to the printing services of PRINT=2 only
#   when PARAM is defined.
#
#   GETENV={0|1}
#   When using PRINT=3 or PRINT=4, GETENV=1 will cause pget.awk to override
#   the parameter's value with the value of the corresponding environment
#   variable, if it exists.  Only useful when PARAM is defined.
#
#   DEFAULT=x
#   If the values of SECTION and PARAM would normally produce no output,
#   pget.awk prints the DEFAULT value instead, if DEFAULT is defined.  If
#   the DEFAULT is printed, it is not subject to DEBLANK, TRIM, or JOIN.
#   Furthermore, processing of TEST precedes DEFAULT, so that TEST works
#   regardless of the value of DEFAULT.
#
#   DEBUG={0|1}
#   pget.awk supports an internal debugging mode that can be enabled
#   using DEBUG=1.  This output is intended for maintainers and advanced
#   users.
#
# DESIGN NOTES
#   pget.awk illustrates a common design technique that the author tends
#   to call hunt and gather.  awk is an exceptionally well-suited tool for
#   this technique because awk's default mode is to hunt for lines matching
#   regular expressions.
#
#   Once lines of interest are identified by hunting, gather mode is enabled
#   and all subsequent input lines are saved in an array.  Hunting continues
#   while gathering, so that pget.awk might know when to disable gather mode.
#
#   Gather mode is used to collect the section contents.  After all input
#   files have been processed and all lines have been gathered, the END
#   block of pget.awk is used to inspect these gathered lines and search
#   for parameters.  The END block builds a second array that contains
#   the lines to output, and, finally, this array is printed to stdout.
#
#   Inside the END block, PRINT=n selects the type of output processing
#   based upon n.
#
#   To support an implied section, gather mode must be initially enabled.
#
#   If you look carefully at pget.awk code, you'll notice that when searching
#   for parameters, pget.awk tends to ignore gathered lines that don't follow
#   the name=value model.  Thus, this input,
#
#       [hello]
#       you called?
#       hello = world
#       what do you want now, I don't know
#       term = xterm
#
#   which should probably be,
#
#       [hello]
#       ;you called?
#       hello = world
#       ;what do you want now, I don't know
#       term = xterm
#
#   is, generally speaking, treated the same.  That is, pget.awk does the
#   right thing with both styles of input.  Indeed, restrictions on the
#   input file will generally come from other programs, not pget.awk.
#
# DESIGN RULES
#   1. Comments starting with ';' in column one are line comments and are
#      always removed.
#
#   2. Comments starting with '#' as the first nonwhite character are
#      line comments but may or may not be removed.  If the line is a
#      continuation line it is always kept, otherwise it is removed,
#      unless KEEPHASH=1 is defined.
#
#   3. Trailing comments start with '#' and may appear anywhere after
#      the equal sign.
#
#   4. Blank lines before and after a section are ignored.  But blank
#      lines intermixed in a section are printed if PARAM is undefined.
#      Use DEBLANK=1 to suppress these blank lines.
#
#   5. Blank lines continued are preserved.
#
#   6. Section headers are introduced only by a '[' in column one.
#
#   7. A valid section header must have ']' as the last nonwhite
#      character on the line.
#
#   8. Whitespace in SECTION and PARAM names is significant.
#
#   9. If PARAM is undefined, parameter definitions are ignored.  This
#      is a feature, not a bug.  See CAVEATS.
#
#   10. Whitespace before or after the equals '=' is removed.
#
#   11. Whitespace before or after the parameter definition is removed.
#
#   12. Whitespace before or after the continuation character '\' is
#       insignificant.  The '\' must be the last nonwhite character.
#
#   13. All whitespace in continuation lines is significant, except for
#       whitespace before and after the continuation character '\' (if
#       present), which is stripped.
#
#   14. Parameter definitions defined as empty result in no output.
#
#   15. Empty parameter definitions continued, ie, "NAME = \", are handled
#       properly.  No initial blank line is output by an empty definition
#       continued.
#
#   16. Embedded continuation markers are preserved, ie, "NAME = \\",
#       works as expected.
#
#   17. Same name parameters in the same section all get extracted.
#
#   18. Same name parameters in different sections are different.
#
# EXAMPLES
#   Assuming this input,
#
#       [general]
#       SCRIPT = \
#       #!/bin/sh \
#       echo hello world \
#       echo goodbye world
#
#   with this command,
#
#       pget.awk SECTION=general PARAM=SCRIPT
#
#   results in this output,
#
#       #!/bin/sh
#       echo hello world
#       echo goodbye world
#
#   But if the input was re-written like this,
#
#       [general]
#       #!/bin/sh
#       echo hello world
#       echo goodbye world
#
#   then this command,
#
#       pget.awk SECTION=general KEEPHASH=1
#
#   would produce the same output.
#
# TIPS
#   1. Remember that PARAM and SECTION are regular expressions.
#
#   2. Using PARAM='*' or SECTION='*' is not what you want, these should
#      be PARAM='.*' and SECTION='.*', respectively.  See Tip #1.
#
#   3. The implied section allows some interesting organization choices.
#      For example, the implied section can be used to store official notes
#      describing the input.  This embedded documentation is viewable just
#      by specifying 'pget.awk filename'.  Therefore, the implied section
#      can be ideal for documenting the purpose of the file, such as the
#      different section header names.
#
#   4. Since pget.awk prints section contents if PARAM is undefined,
#      pget.awk can be used to build a shar like archive, where section
#      names are well known names.  The contents of each archive section
#      are retrievable by specifying SECTION=<archive section>.
#
#   5. For line comments, ';' is the absolute comment character, meaning
#      only ';' can remove lines from the output for all cases.  Using
#      line comments starting with '#' still makes the lines retrievable
#      using KEEPHASH=1.
#
#   6. Using KEEPHASH=1 may allow you to design internal parameter
#      definitions, ie, '#name = value' is retrievable if KEEPHASH=1
#      and PARAM="#name" is specified.
#
#   7. The case of SECTIONs and PARAMs *is* significant, but pget.awk
#      does not enforce any particular case policy.  If you need case
#      insensitivity, define it yourself, like this,
#
#        Case Sensitive
#          pget.awk SECTION=general ...
#
#        Case Insensitive
#          pget.awk SECTION="[Gg][Ee][Nn][Ee][Rr][Aa][Ll]" ...
#
# CAVEATS
#   1. Specifying case insensitive SECTION and PARAM variables is a
#      royal pain.  There ought to be a better way.
#
#      * There is, use gawk's IGNORECASE=1 option.
#
#   2. Specifying SECTION="[name]" is probably not what you want.
#      Don't delimit your section name with outer brackets, pget.awk
#      does that for you internally.  Use SECTION="name" instead.
#
#   3. Using JOIN and JOINC together works correctly but is probably
#      not what you want.  Use JOINC if your PARAM selects multiple
#      parameter names.  That is, if PARAM is empty or you specify a
#      regular expression, pget.awk may find multiple parameters; it
#      is this situation where JOINC is useful.
#
#   4. If you specify JOIN=1, you always get deblanking and trimming.
#      That is, trying to force suppress these by specifying JOIN=1
#      with DEBLANK=0 TRIM=0 doesn't work.  This is by design.
#
#   5. pget.awk never removes '#' line comments continued, these
#      line comments are assumed to be significant.  (Otherwise, you
#      wouldn't have put a continuation marker on that line, right?)
#      Use ';' in column one to comment out a continuation line.
#
#   6. TRIM=1 always works.  In general, you shouldn't consider any
#      whitespace as significant, as pget.awk strips quite a bit of
#      whitespace even when TRIM is undefined.
#
#   7. Specifying PARAM=";name" never works.  Using PARAM="#name"
#      only works if KEEPHASH=1 is specified.  This is by design.
#
#   8. A line containing the string "[]" is not a valid section
#      header; at least one character must appear between the brackets.
#
#   9. You can design some sections to be content sections with no
#      parameters, while other sections contain only parameter definitions.
#      Mixing content with parameter definitions in the same section works
#      correctly, but may not be very useful.  (However, using KEEPHASH=1
#      and '#' to mark private variables in content sections can be
#      incredibly useful.)
#
#   10. Use of PRINT=3 and PRINT=4 should be considered experimental and
#       may not work for all cases, e.g., parameter definitions continued.
#
#   11. Use of PRINT=3 and PRINT=4 is only useful when PARAM is defined,
#       thus you may need to specify PARAM='.*' to get what you want.
#
#   12. pget.awk has been tested with GNU's gawk, FreeBSD's nawk, and
#       to some extent, with Solaris's nawk.  Changing the she-bang line
#       at the top to gawk is an excellent choice.  FreeBSD nawk uses
#       the One True Awk, available at http://cm.bell-labs.com/who/bwk.
#
#   13. pget.awk will probably fail with original awk, such as /bin/oawk
#       on Solaris.
#
# LAST REVISION
#   $Id: pget.awk,v 1.40 2007/08/06 15:39:14 david4 Exp $

## -- print debugging output
function debug(s) {
    if (DEBUG) print "DEBUG: pget.awk: " s
}

## -- helper function to enable/disable gather mode
function gathering(n) {
    debug("GATHERING: " (n ? "enabled" : "disabled"))
    gather = n
}

## -- strip trailing comments from value
function stripcmtv(s) {
    sub(/#.*$/, "", s)
    sub(/[ \r\t]+$/, "", s)
    return s
}

## -- check for continulation line, stripping marker if requested
function iscon(s, stripmarker) {
    if (s ~ /\\$/) {
        debug("Matched: continuation line")
        continueline = 1
        if (stripmarker) {
            s = substr(s, 1, length(s)-1)
            sub(/[ \r\t]+$/, "", s)
            }
        }
    else if (s ~ /\\[ \r\t]*#.*$/) {
        debug("Matched: continuation line (and trailing comment)")
        continueline = 1
        if (stripmarker) {
            sub(/\\[ \r\t]*#.*$/, "", s)
            sub(/[ \r\t]+$/, "", s)
            }
        }
    else continueline = 0
    return s
}

## -- special postprocessing of a gathered definition
## -- if PRINT == 0 return value
## -- if PRINT == 1 return name
## -- if PRINT == 2 return definition as-is
## -- if PRINT == 3 return definition for sh
## -- if PRINT == 4 return definition for sh with export
function clean(s,  stmp) {
    if (PRINT == 0) {
        # strip parameter name, leaving value
        sub(MATCH, "", s)
        sub(/^[ \r\t]+/, "", s)
        s = stripcmtv(s)
        }
    else if (PRINT == 1) {
        # strip value, leaving parameter name
        sub(/^[ \r\t]+/, "", s)
        sub(/[ \r\t]*=.*$/, "", s)
        }
    else if (PRINT == 3 || PRINT == 4) {
        # squeeze away superfluous spaces
        sub(/^[ \r\t]+/, "", s)
        sub(/[ \r\t]*=[ \r\t]*/, "=", s)
        s = stripcmtv(s)
        if (GETENV) {
            stmp = s
            sub(/\=.*$/, "", stmp)
            if (length(ENVIRON[stmp]) > 0) 
		s = stmp "=" ENVIRON[stmp]
            }
        # quote value for shell definition
        sub(/\=/, "=\"", s)
        sub(/$/, "\"", s)
        if (PRINT == 4) {
            stmp = s
            sub(/^/, "export ", stmp)
            sub(/\=.*$/, "", stmp)
            s = s " ; " stmp
            }
        }
    return s
}

## -- helper function to append blank line to gather array
function saveblank(n) {
    while (n--) {
        debug("GATHERING: NR=" NR ",nline=" nline+0 ": <blankline>")
        line[nline++] = ""
        }
}

## -- helper function to append input line to gather array
function saveline(s) {
    if (length(s) > 0 ) {
        debug("GATHERING: NR=" NR ",nline=" nline+0 ": \"" s "\"")
        line[nline++] = s
        }
}

## -- store processed value for later output
function storev(s) {
    if (length(s) > 0)
        value[nvalue++] = s
}

## -- copy processed values back to line array
function cpvtol() {
    for (nline = 0; nline < nvalue; ++nline)
        line[nline] = value[nline]
}

## -- initialize internal global variables
BEGIN {
    implied = 1
    gather = 1
}

## -- always skip these line comments
/^[ \r\t]*;/ {
    next
}

## -- may need to keep these comments
/^[ \r\t]*#/ {
    if (!KEEPHASH && !continueline) next
}

## -- skip blank lines, but count them
/^[ \r\t]*$/ {
    continueline = 0
    if (!DEBLANK) ++blankline
    next
}

## -- enable gathering if matching section
## -- disable gathering on all other sections
## -- flush all lines previously gathered
/^\[.+\][ \r\t]*$/ {
    blankline = 0
    continueline = 0
    if (SECTION && implied) {
        debug("FLUSHING IMPLIED SECTION")
        nline = 0
        implied = 0
        }
    if (SECTION && match($0, "^\\[" SECTION "\\][ \r\t]*$")) {
        debug("FOUND SECTION: \"" $0 "\"")
        if (PRINT && !PARAM) {
            gathering(PRINT >= 2)
            sub(/^\[/, "")
            sub(/\][ \r\t]*$/, "")
            if (PRINT == 2) {
                $0 = "[" $0 "]"
                saveblank(nline > 0)
                }
            else if (PRINT == 3 || PRINT == 4)
                $0 = ""
            saveline($0)
            }
        else
            gathering(1)
        }
    else {
        debug("SKIPPING SECTION: \"" $0 "\"")
        gathering(0)
        }
    next
}

## -- if gathering input lines, save input line in array,
## -- otherwise the input line is discarded; but first
## -- recreate all intervening blank lines; note
## -- since this code never actually sees the blank
## -- line itself, all trailing blank lines in the
## -- section are conveniently discarded
{
    if (!gather) next
    if (!(JOIN || DEBLANK))
        saveblank(blankline)
    blankline = 0
    continueprev = continueline
    if ($0 ~ /\\[ \r\t]*$/)
        continueline = 1
    else
        continueline = 0
    # join continuation lines together?
    if (JOINC) {
        if (continueline || continueprev) {
            sub(/[ \r\t]*\\[ \r\t]*$/, "")
            sub(/^[ \r\t]+/, "")
            if (continueprev) {
                if (JOINC ~ /[0-9]+/) JOINC = " "
                debug("APPENDING: NR=" NR ",nline=" nline-1 ": " $0)
                line[nline-1] = line[nline-1] JOINC $0
                next
                }
            }
        }
    saveline($0)
}

## -- main engine to extract values from gathered lines
## -- here we inspect and process all gathered lines
## -- finally, all output lines are printed
END {
    if (SECTION && implied) {
        # if have SECTION but implied still true then no
        # section headers were found, and therefore no
        # output lines will be produced
        debug("Section \"[" SECTION "]\" not found, flushing all gathered lines")
        nline = 0
        }
    else if (PARAM) {
        # for each gathered line that matches PARAM do
        #   continuation line processing
        #   PRINT output processing
        #   save processed value (if any) to array
        # end
        debug("Try matching \"" PARAM "\" in " nline+0 " gathered lines")
        MATCH = "^[ \r\t]*" PARAM "[ \r\t]*="
        continueline = 0
        for (x = 0; x < nline; ++x) {
            v = line[x]
            sub(/[ \r\t]+$/, "", v)
            if (continueline) {
                v = iscon(v, !PRINT || JOIN)
                if (PRINT == 1) v = ""
                if (length(v) == 0 && !PRINT && continueline && !DEBLANK) {
                    # blank lines continued are preserved
                    value[nvalue++] = ""
                    }
                else {
                    if (v !~ /^[ \r\t]*#/) {
                        # strip trailing comment before continuation marker
                        # but leave line comments alone
                        v = stripcmtv(v)
                        }
                    storev(v)
                    }
                }
            else if (v ~ MATCH) {
                debug("Matched: nline=" x ": \"" v "\"");
                if (length(v) == 0) continue
                v = iscon(v, !PRINT || JOIN)
                v = clean(v)
                storev(v)
                }
            }
        cpvtol()
        }
    else if (!SECTION && PRINT) {
        # if SECTION empty and PARAM empty then
        # check if PRINT > 0 requires more processing
        # otherwise all gathered lines are printed as-is
        continueline = 0
        for (x = 0; x < nline; ++x) {
            v = line[x]
            sub(/[ \r\t]+$/, "", v)
            if (continueline) {
                iscon(v, 0)
                if (PRINT == 1) v = ""
                }
            else {
                if (length(v) == 0) continue
                iscon(v, 0)
                v = clean(v)
                }
            storev(v)
            }
        cpvtol()
        }

    # mimic test -z primitive
    if (TEST == "z") {
        if (nline) exit 1
        else exit 0
        }

    # mimic test -n primitive
    if (TEST == "n") {
        if (nline) exit 0
        else exit 1
        }

    # here we trim all leading & trailing whitespace;
    # except for leading whitespace in continuation lines,
    # all whitespace trimming has already been done for
    # parameter definitions but whitespace trimming of
    # the section contents has not occurred at all
    if (TRIM || JOIN) {
        for (x = 0; x < nline; ++x) {
            sub(/^[ \r\t]+/, "", line[x])
            sub(/[ \r\t]+$/, "", line[x])
            }
        }

    # here we concatenate all output lines, if necessary
    if (JOIN) {
        if (JOIN ~ /[0-9]+/) JOIN = " "
        for (x = 0; x < nline; ++x) {
            if (line[x] || JOIN != " ") {
                if (j)
                    j = j JOIN line[x]
                else
                    j = line[x]
                }
            }
        # reset array for single output line
        if (j) {
            nline = 1
            line[0] = j
            }
        else nline = 0
        }

    # if no output, use DEFAULT, if provided
    if (nline == 0 && DEFAULT)
        line[nline++] = DEFAULT

    # all program output is done from here
    for (x = 0; x < nline; ++x)
        print line[x]

    # our exit status is based upon output produced
    if (nline) exit 0
    else exit 1
}

#--------------------------------------------------------------------
# *** BEGIN MODIFICATION HISTORY ***
#
# Revision #       Date      Time    Changes By
# ------------  ---------- --------  ----------
# $Log: pget.awk,v $
# Revision 1.40  2007/08/06 15:39:14  david4
# Minor updates to contact information.
#
# Revision 1.39  2006/12/22 01:30:25  david4
# Fixed some typos.
#
# Revision 1.38  2006/12/22 01:23:56  david4
# Accept any line comment with leading whitespace.
#
# Revision 1.37  2006/12/10 00:23:42  david4
# Strip trailing comment before continuation marker, but
# leave line comments alone.
#
# Revision 1.36  2006/12/10 00:04:07  david4
# Handle trailing comments on continuation lines
# Add functions: iscon, store, cpvtol.
# Updated documentaion to better discuss design notes
# and comment processing.
#
# Revision 1.35  2006/12/09 21:12:51  david4
# Fix bug found via automated testing.  Extra blank line
# was added when !PARAM && PRINT, appears to have been
# caused by recent code 'cleanup' effort.  Arrgh.
#
# Revision 1.34  2006/12/07 18:34:20  david4
# Added support for removing trailing '#' comments.
# Updated documentation, added new COMMENT PROCESSING discussion.
# Moved PRINT==0 cleaning to clean() function.
# Added stripcmt() function.
# Added saveblank() and saveline() functions to streamline logic.
# Small areas of minor code reorg/rewrite to better use awk language.
#
# Revision 1.33  2006/12/06 19:20:46  david4
# Fix minor typo in comments of gathering function.
#
# Revision 1.32  2006/12/06 19:18:59  david4
# Create new 'gathering' function to help enable/disable
# gather mode and print debugging information at same time.
#
# Revision 1.31  2006/12/06 18:50:56  david4
# Minor cleanup of gathering enable/disable debug messages.
# When SECTION found, fix bugs in (!PARAM && PRINT) block.
#  1. Don't pre-gather section header if PRINT==3 || PRINT==4.
#  2. Enable gathering if PRINT>=2, not just PRINT==2.
#
# Revision 1.30  2006/12/02 03:06:38  david4
# Minor fixes to documentation.
#
# Revision 1.29  2006/12/02 02:11:24  david4
# Minor update to documentation, prefer to show GNU's website
# rather than FSF's snail mail address when discussing details
# of more information on GPL.
#
# Revision 1.28  2006/12/02 02:01:19  david4
# Major reorganization/update of comments (removed references
# to nawk's -v option, for example).
# Added GNU licensing to documentation.
# Added function clean() to postprocess a gathered string,
# resulting in better readability since it eliminated some
# duplicate code.
# Fixed bug where blank lines continued were not properly
# being preserved.
# Some minor compatibility testing with Solaris nawk.
#
# Revision 1.27  2003/06/03 09:06:59  davidt
# Updates to documentation, more examples for JOINC.
#
# Revision 1.26  2003/05/11 09:01:35  davidt
# Fixed missing braces when stripping continuation marker when JOIN=1.
#
# Revision 1.25  2003/05/11 08:39:51  davidt
# Remove EXPORT=1 but reincarnate as PRINT=4.
# Rename ENVFIRST --> GETENV.
# As before, PRINT={3|4} and GETENV are in slight limbo
# as I decide on the best interface to these features.
#
# Revision 1.24  2003/05/06 19:55:45  davidt
# Added PRINT=3 to print parameter definitions in form suitable
# for use by the shell.  When PRINT=3, check for EXPORT=1 and
# ENVFIRST=1 to modify these shell variable definitions.
#
# Revision 1.23  2002/04/25 12:32:38  davidt
# Fix this warning from gawk 3.1,
# gawk: pget.awk:582: warning: escape sequence `\]' treated as plain `]'
#
# Revision 1.22  2002/03/06 14:22:46  davidt
# Fix bug: failed to print value of parameter if the value
# was defined as 0.  That is, this command failed,
#   pget.awk SECTION=hello PARAM=world foo
# if file foo had these contents,
#   [hello]
#   world=0
# This defect has now been fixed.
#
# Revision 1.21  2002/02/20 18:25:11  davidt
# Added JOINC to fix deficiency: when printing multiple parameters
# and these parameters were all using continuation lines, the
# JOIN feature by itself was inadequate; since it would concat
# all output lines onto 1 line.  JOINC corrects this and joins
# the continuation lines of each parameter only.  JOIN should
# probably be renamed to JOINALL (or something else completely).
#
# Revision 1.20  2001/07/22 22:50:34  davidt
# Updates to help documentation.
#
# Revision 1.19  2001/07/20 01:09:33  davidt
# Remove GREP variable; substitute with PRINT; allow {0|1|2} values.
# Support output of PARAM or SECTION names only, via PRINT=1.
# Support output of PARAM definitions or complete SECTION, if PRINT=2.
# Use PRINT=0 to mean normal default output mode.
# Updated documentation.
#
# Revision 1.18  2001/07/19 14:38:32  davidt
# Standardize on gawk.
#
# Revision 1.17  2001/05/23 14:33:33  davidt
# Fix documentation error.
#
# Revision 1.16  2001/05/21 21:27:11  davidt
# Update documentation, prepare for man2html extraction.
#
# Revision 1.15  2001/05/01 12:09:00  davidt
# Print DEFAULT variable (if defined) if otherwise no output.
# Set exit status to reflect if output was printed.
# Change DEBUGGING to DEBUG.
#
# Revision 1.14  2001/04/18 12:15:18  davidt
# Change #!/bin/nawk to #!/usr/bin/nawk; slightly more portable. (maybe)
# Fix bug: JOIN now works for empty continuation lines.
# Add \r when checking for whitespace.
#
# Revision 1.13  2001/04/18 11:25:16  davidt
# Changes to documentation to support wider distribution.
#
# Revision 1.12  2001/04/12 18:06:13  davidt
# Better debug() messages for GATHERING mode.
#
# Revision 1.11  2001/04/04 15:28:10  davidt
# Changes for new GREP=1 feature.
# Don't recognize [] as a section header.
#
# Revision 1.10  2001/04/02 12:46:29  davidt
# Lines with section headers must now have ']' as last nonwhite character.
# Fixes problem of '[' in column 1 when it's actually start of shell '[' command.
#
# Revision 1.9  2001/04/02 12:23:34  davidt
# Restore '#' as a comment character, but with exceptions.
#
# Revision 1.8  2001/03/27 23:54:44  davidt
# Rename global variable "found" to more meaningful "implied".
# Changes to support implied, which is initialized to true.
# Fixes flushing of implied section at correct time.
# Abandoned '#' as comment character.
# Updates to some debug() output.
#
# Revision 1.7  2001/03/27 22:48:52  davidt
# Flush gathered lines only for implied section.
#
# Revision 1.6  2001/03/25 20:57:50  davidt
# Add TEST={n|z} variable to mimic test primitives.
#
# Revision 1.5  2001/03/25 03:06:00  davidt
# Better feature advertisement for same name parameters.
# Fix bug: suppress all empty parameter definitions.
# Advertise [DEBUGGING=1] in synopsis.
#
# Revision 1.4  2001/03/24 15:28:17  davidt
# Fix bug: if have SECTION but not found, flush gathered lines
# Added debugging support, specify DEBUGGING=1 to enable.
#
# Revision 1.3  2001/03/24 15:00:59  davidt
# Fix bug: flush gathered lines at start of all sections.
#
# Revision 1.2  2001/03/24 14:36:39  davidt
# Added extensive new comments.
# Removed requirement for awk's -v option.
# Added JOIN, TRIM, and DEBLANK variables.
# Changes to support implied section.
# Fix bug: preserve all whitespace in continued lines.
#
# Revision 1.1  2001/03/23 20:14:24  davidt
# Initial Checkin.
#
# *** END MODIFICATION HISTORY ***
#--------------------------------------------------------------------
