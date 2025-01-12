if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal nosmartindent
setlocal nolisp
setlocal autoindent

setlocal indentexpr=GetJaiIndent(v:lnum)
setlocal indentkeys+=;

let s:jai_indent_defaults = {
      \ 'default': function('shiftwidth'),
      \ 'case_labels': function('shiftwidth') }

function! s:indent_value(option)
    let Value = exists('b:jai_indent_options')
                \ && has_key(b:jai_indent_options, a:option) ?
                \ b:jai_indent_options[a:option] :
                \ s:jai_indent_defaults[a:option]

    if type(Value) == type(function('type'))
        return Value()
    endif
    return Value
endfunction

let s:skip_hlgroup = [ 'string', 'comment' ]

function! s:Skip()
    let syn = synIDattr( synID(line( '.' ), col( '.' ), 0), 'name' )
    for cand in s:skip_hlgroup
        if syn =~? cand
            return 1
        endif
    endfor
    return 0
endfunction



" TODO: This indent file is extremely slow, sorry. It does some dumb stuff
" mainly due to the correct thing not being all that obvious, but mostly due to
" my laziness and hacking approach;
"
" The indent style for this code is Ben's style. that is:
"
" foo {
"   <indent after block>
" }
"
" call_function(
"   indent here,
"   next arg
" );
"
" call_function(
"   indent here,
"   next arg );
"
" call_function( indent here,
"                next arg );
"
" if x == {
"   case foo; {
"      indent here;
"   }
"   case bar:
"     indent here too;
"     #through
" }
"
" define_function :: ( para: P ) {
"    ...
" }
"
" define_function :: ( para: P,
"                      gone: G ) {
"    stuff here..., not  ~here
" } @note
"
" #scope_file
"
" foo :: bar;
" S :: struct {
"    x: string;
"    y: float;   @"Note";
" }
"
" // the following is a bit questionable, and doesn't work perfectly,
" // particularly for quirks like how heredocs don't end in a semicolon
"
" thing_that
"   doesn't look like a complete
"       statement;
" next thing;

function! s:SearchParensPair()

    let line = line('.')
    let col = col('.')

    " Search for parentheses
    call cursor(line, col)
    let parlnum = searchpair('(', '', ')', 'bW', function( 's:Skip' ) )
    let parcol = col('.')
    let inside_other = parlnum > 0

    " Search for brackets
    call cursor(line, col)
    let par2lnum = searchpair('\[', '', '\]', 'bW', function( 's:Skip' ) )
    let par2col = col('.')
    let inside_other = inside_other || par2lnum > 0

    " Search for braces
    call cursor(line, col)
    let par3lnum = searchpair('{', '', '}', 'bW', function( 's:Skip' ) )
    let par3col = col('.')

    " Get the closest match
    if par2lnum > parlnum || (par2lnum == parlnum && par2col > parcol)
        let parlnum = par2lnum
        let parcol = par2col
    endif
    let is_brace = 0
    if par3lnum > parlnum || (par3lnum == parlnum && par3col > parcol)
        let parlnum = par3lnum
        let parcol = par3col
        let is_brace = 1
    endif

    " Put the cursor on the match
    if parlnum > 0
        call cursor(parlnum, parcol)
    endif
    return [ parlnum, is_brace, inside_other ]
endfunction

function! s:LooksLikeCaseLabel( l )
    return a:l =~# '\m^\s*case.*;\(\s*{\)\?\s*$'
endfunction

function! s:EndsAStatementMaybe( l, lnum )
    let l = substitute( a:l, '//.*$', '', '' )

    if l =~# '\m^\s*$'
        return 1
    elseif l =~# '\m{\s*$'
        return 1
    elseif s:ClosesBlock( l )
        return 1
    elseif l =~# '\m;'
        " FIXME: any semicolon will do... is probably not right
        return 1
    elseif l =~# '\m,\s*$'
        call cursor( a:lnum, len( l ) )
        let is_in_func = searchpair( '(', '', ')', 'bW', function( 's:Skip' )  ) > 0
        "echom "EndsAStatementMaybe: " l " give " is_in_func
        return !is_in_func
    elseif l =~# '\m^\s*#scope'
        return 1
    else
        return 0
    endif
endfunction

function! s:ClosesBlock( l )
    return a:l =~# '\m}\(\s*;\)\?\s*\(@.*\)\?\s*$'
endfunction

function! GetJaiIndent(lnum)
    let prev = prevnonblank(a:lnum-1)

    if prev == 0
        return 0
    endif

    let col = col( '.' )
    let inserted_col = col - 1
    let prevline = getline(prev)
    let line = getline(a:lnum)

    let ind = indent(prev)

    "echom "Starting with" ind

    if inserted_col > 1 && line[ inserted_col - 1 ] ==# ';'
        " we just entered a ; (probably). Only re-indent if this looks like a
        " case label
        if !s:LooksLikeCaseLabel( line[ 0: inserted_col - 1 ] )
            " it doesn't look one, so just return the current indent
            return indent( line )
        endif
    endif

    " When a character has just been inserted and indent is triggered, the
    " cursor (col) is just _after_ the newly inserted character. (unless
    " indentkeys says otherwise, which is not the typical default)
    " So often we want to base our decisions on the character just-inserted
    " (i.e. col - 1). But this is tricky for sequences like #     };# where
    " relying on the char of the ; will calculate the wrong indent level - i.e.
    " outside the preceding }. we could scan backwards or something, but instead
    " we do what the = command does and always use the first character on the
    " current line - i.e. work out where the fist char on the line should be -
    " that's the indent!

    call cursor( a:lnum , 1 )
    if s:Skip()
        return ind
    endif

    " First see if we should line up with an opening ( or [
    let [ parlnum, is_brace, inside_other ] = s:SearchParensPair()
    if parlnum > 0
        " We're in some kind of open parent, braces, or brackets
        let parcol = col('.')
        let closing_paren = match(getline(a:lnum), '\m^\s*[])}]') != -1
        if match(getline(parlnum), '\m[([{]\s*$', parcol - 1) != -1
            " The opening line opened the dict/list/tuple, without
            " any additional stuff, e.g.:
            " x := .{
            " y := [
            " a(
            " x :: inline (
            "
            " But, if we added something in between, then we should use its
            " indent
            if closing_paren
                " we're closing it; use the indent of the opening line
                "echom "use indent of openeing line"
                let ind = indent(parlnum)
            else
                " use indent of opening line + 1 sw
                "echom "use indent of openeing line +1"
                let ind = indent(parlnum) + s:indent_value( 'default' )
            endif
            if inside_other || !is_brace
                return ind
            endif
        else
            " The opening line opened the dict/list/tuple, with
            " additional stuff, e.g.:
            " x = { 'test': test
            " y = [ test
            " z = ( test
            " a( test,
            " x :: inline b( test : Foo,
            if closing_paren
                " This lines it up with the bracket (strange ... -1 )
                "echom "line up with bracket"
                let ind = parcol - 1
            else
                " lines it up with the first char of the stuff
                "echom "line up with first cahr"
                let ind = matchend(getline(parlnum), '\m[([{]\s*', parcol - 1)
            endif
            if inside_other || !is_brace
                return ind
            endif
        endif
    endif

    " to find the indent of the current block
    call cursor( a:lnum, 1 )
    let block = searchpair( '{', '', '}', 'bW', function( 's:Skip' )  )
    if block > 0
        " Find the next non-empty line prior to the start of the block and use
        " its indent ?
        "
        " need to deal with things like this:
        " typicaly i have something that tries to find the smallest indent of
        " the "block of lines" containing the opening brace.. but does that
        " always work?
        "
        " parse_digits :: inline ( using parser: *Parser,
        "                 number : *string,
        "                 max_digits: s64 = -1,
        "                 $base: DigitBase = .DEC ) -> s64 {

        let blnum = block - 1
        let mindent = indent( block )
        while blnum > 0
            let bl = getline( blnum )
            call cursor( blnum, len( bl ) )
            if s:Skip()
                let blnum -= 1
                continue
            endif
            " if it's empty, or looks like the end of a statement
            if s:EndsAStatementMaybe( bl, blnum )
                "echom 'line' blnum 'ends a statement, probably. using mind ' mindent
                break
            endif

            " FIXME/TODO: This doesn't work in this case:
            "         if data[ pos ] == {
            "             case #char "\"";
            "               #through;
            "             xxx // <-- here
            "
            " for xxx line we end up finding the { of the if ... but we really
            " want the intervening case label + indent. that would require
            " bascially always searching backwards manually rather than
            " searchpair. It works ok for this:
            "
            " case x: {
            " }
            "
            " Annoyinglythe naive "use the indent of the previous line" works
            " well though!
            "
            let i = indent( blnum )
            if i < mindent
                let mindent = i
            endif
            let blnum -= 1
        endwhile

        " " now check for case labels!
        if !s:LooksLikeCaseLabel( line ) && line !~# '\m^\s*}'
            let clnum = a:lnum - 1
            while clnum > blnum
                let l = getline( clnum )
                call cursor( clnum, len( l ) )
                if s:Skip()
                    let clnum -= 1
                    continue
                endif

                if s:LooksLikeCaseLabel( l )
                    let mindent = indent( clnum )
                    break
                elseif l =~# '\m^\s*}'
                    " Close of a an intervening block, so ignore it
                    break
                endif
                let clnum -= 1
            endwhile
        endif

        if line !~# '^\s*}'
            let ind = mindent + s:indent_value( 'default' )
        else
            let ind = mindent
        endif
    endif

    " Try to determine if we should dedent. slowly, repeating a load of
    " already-calculated stuff.
    "
    " Please don't kill me.
    "
    " This could all be a ton more efficient, and less wasteful.
    "
    " But for now, i just want it to work robustishly; we can make fast later..

    " OK it doesn't work robustishly even now. It's a horrible mess and needs
    " redoing with some actual thought.

    " Find the column of the first 'block' closer on this line
    "
    " matchend returns index of char after the match, so we want matchend-1, but
    " we also want a 1-based column, so matchend-1+1 = matchend.
    let bracket_col = matchend( line, '\m^\s*]' )
    let paren_col = matchend( line, '\m^\s*)' )

    if bracket_col >= 0
        call cursor( a:lnum, bracket_col )
        let starting = searchpair( '[', '', ']', 'bW', function( 's:Skip' )  )
        if starting > 0
            "echom "Matching [ at" starting ", so using" indent(starting)
            return indent( starting )
        endif
    elseif paren_col >= 0
        call cursor( a:lnum, paren_col )
        let starting = searchpair( '(', '', ')', 'bW', function( 's:Skip' )  )
        if starting > 0
            "echom "Matching ( at" starting ", so using" indent(starting)
            return indent( starting )
        endif
    elseif !s:EndsAStatementMaybe( prevline, prev )
        " Maybe a hangling indent
        " TODO! check for gnarly cases:
        "  - #scope_file = no terminal semicolon
        "  - #string FOO = ends with FOO (no semicolon)!
        let ind += s:indent_value( 'default' )
    endif

    return ind
endfunction
