" Vim compiler file
" Compiler:         Jai
" Maintainer:       Raphael Luba <raphael@leanbyte.com>
" Latest Revision:  2020-10-05

if exists("current_compiler")
  finish
endif
let current_compiler="jai"

let s:cpo_save = &cpo
set cpo&

function! s:FindJaiEntrypoint()
    let start = expand( '%:p:h' )
    let buildfiles = [ 'first.jai', 'build.jai' ]

    if exists( 'b:jai_entrypoint' )
        return [ b:jai_entrypoint ]
    elseif exists("g:jai_entrypoint")
        return [ g:jai_entrypoint ]
    endif

    for buildfile in buildfiles
        let found = findfile(buildfile, start .. ';')
        if ! empty( found )
            " use abs path to avoid wierdness of user changes directory
            return [ fnamemodify( found, ':p' ) ]
        endif
    endfor

    return [ expand( '%' ) ]
endfunction

function! s:FindJaiCompiler()
    if exists("g:jai_compiler")
        return g:jai_compiler
    elseif has("win64") || has("win32") || has("win16")
        return "jai.exe"
    elseif executable( 'jai' )
        return 'jai'
    else
        return "jai-linux"
    endif
endfunction

function! s:FindJaiModules()
    if exists("g:jai_local_modules")
        return [ '-import_dir', g:jai_local_modules ]
    endif

    let start = expand( '%:p:h' )
    for modules_dir_candidate in [ 'local_modules', 'modules' ]
      let modules_dir = finddir( modules_dir_candidate, start .. ';' )
      if !empty( modules_dir )
        " Use abs path to avoid wierdness and having to make modules_dir
        " relative to start (although this is easy, there's no point)
        return [ '-import_dir', fnamemodify( modules_dir, ':p' ) ]
      endif
    endfor
    return []
endfunction

function! s:GetJaiMakeprg()
    let b:jai = s:FindJaiCompiler()
    let b:jai_args =
          \ [ '-no_color' ] + s:FindJaiModules()
    return b:jai . ' ' . join( b:jai_args + s:FindJaiEntrypoint(), ' ' )
endfunction

function! UpdateJaiMakeprg()
    let makeprg = s:GetJaiMakeprg()

    let no_output = '{'
          \ .. 'c :: #import "Compiler";'
          \ .. 'c.set_build_options_dc( .{ do_output=false } );'
          \ .. '}'

    let b:neomake_jai_enabled_makers = [ 'jai' ]
    let b:neomake_jai_jai_maker = {
          \ 'exe': b:jai,
          \ 'args': b:jai_args + [ '-run', no_output ] + s:FindJaiEntrypoint(),
          \ 'append_file': 0,
          \ }

    let &l:makeprg=makeprg
endfunction

call UpdateJaiMakeprg()

CompilerSet errorformat=
	\%f:%l\\,%c:\ Error:\ %m,
	\%f:%l\\,%c:\ %m,
	\%m\ (%f:%l),
execute 'CompilerSet makeprg=' . escape(s:GetJaiMakeprg(), ' ')

let &cpo = s:cpo_save
unlet s:cpo_save
