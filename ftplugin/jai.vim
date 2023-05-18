if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:function_definition='%(<\w+>\_s*:[:=]%(\_s*inline)?\_s*\(%(\.\{\|\_[^\{;]){-}\)%(\.\{\|\_[^{;])*\{)'
let b:next_toplevel='\v%$\|^'.b:function_definition
let b:prev_toplevel='\v%^\|^'.b:function_definition
let b:next='\v%$\|'.b:function_definition
let b:prev='\v%^\|'.b:function_definition

if !exists('g:no_plugin_maps') && !exists('g:no_jai_maps')
    execute "nnoremap <silent> <buffer> ]] :<C-U>call <SID>Jai_jump('n', '".b:next_toplevel."', 'W', v:count1)<cr>"
    execute "nnoremap <silent> <buffer> [[ :<C-U>call <SID>Jai_jump('n', '".b:prev_toplevel."', 'Wb', v:count1)<cr>"
    execute "nnoremap <silent> <buffer> ]m :<C-U>call <SID>Jai_jump('n', '".b:next."', 'W', v:count1)<cr>"
    execute "nnoremap <silent> <buffer> [m :<C-U>call <SID>Jai_jump('n', '".b:prev."', 'Wb', v:count1)<cr>"

    execute "onoremap <silent> <buffer> ]] :<C-U>call <SID>Jai_jump('o', '".b:next_toplevel."', 'W', v:count1)<cr>"
    execute "onoremap <silent> <buffer> [[ :<C-U>call <SID>Jai_jump('o', '".b:prev_toplevel."', 'Wb', v:count1)<cr>"
    execute "onoremap <silent> <buffer> ]m :<C-U>call <SID>Jai_jump('o', '".b:next."', 'W', v:count1)<cr>"
    execute "onoremap <silent> <buffer> [m :<C-U>call <SID>Jai_jump('o', '".b:prev."', 'Wb', v:count1)<cr>"

    execute "xnoremap <silent> <buffer> ]] :<C-U>call <SID>Jai_jump('x', '".b:next_toplevel."', 'W', v:count1)<cr>"
    execute "xnoremap <silent> <buffer> [[ :<C-U>call <SID>Jai_jump('x', '".b:prev_toplevel."', 'Wb', v:count1)<cr>"
    execute "xnoremap <silent> <buffer> ]m :<C-U>call <SID>Jai_jump('x', '".b:next."', 'W', v:count1)<cr>"
    execute "xnoremap <silent> <buffer> [m :<C-U>call <SID>Jai_jump('x', '".b:prev."', 'Wb', v:count1)<cr>"
endif

function! s:Jai_jump(mode, motion, flags, count) abort
  if a:mode == 'x'
      normal! gv
  endif

  mark '

  let cnt = a:count
  while cnt > 0
      call search(a:motion, a:flags)
      let cnt = cnt - 1
  endwhile
endfun

" Script for filetype switching to undo the local stuff we may have changed
let b:undo_ftplugin = 'silent! nunmap <buffer> [['
      \ . '|silent! nunmap <buffer> [m'
      \ . '|silent! nunmap <buffer> ]]'
      \ . '|silent! nunmap <buffer> ]m'
      \ . '|silent! ounmap <buffer> [['
      \ . '|silent! ounmap <buffer> [m'
      \ . '|silent! ounmap <buffer> ]]'
      \ . '|silent! ounmap <buffer> ]m'
      \ . '|silent! xunmap <buffer> [['
      \ . '|silent! xunmap <buffer> [m'
      \ . '|silent! xunmap <buffer> ]]'
      \ . '|silent! xunmap <buffer> ]m'
      \ . '|unlet! b:function_definition'
      \ . '|unlet! b:next'
      \ . '|unlet! b:next_toplevel'
      \ . '|unlet! b:prev'
      \ . '|unlet! b:prev_toplevel'
