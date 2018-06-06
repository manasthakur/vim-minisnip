let s:placeholder_texts = []

function! minisnip#ShouldTrigger() abort
    silent! unlet! s:snippetfile
    let s:cword = matchstr(getline('.'), '\v\f+%' . col('.') . 'c')
    let s:begcol = virtcol('.')

    " look for a snippet by that name
    for l:dir in split(g:minisnip_dir, s:pathsep())
        let l:dir = fnamemodify(l:dir, ':p')
        let l:snippetfile = l:dir . '/' . s:cword

        " filetype snippets override general snippets
        for l:filetype in split(&filetype, '\.')
          let l:ft_snippetfile = l:dir . '/_' . l:filetype . '_' . s:cword
          if filereadable(l:ft_snippetfile)
              let l:snippetfile = l:ft_snippetfile
              break
          endif
        endfor

        " make sure the snippet exists
        if filereadable(l:snippetfile)
            let s:snippetfile = l:snippetfile
            return 1
        endif
    endfor

    return search(g:minisnip_delimpat . '\|' . g:minisnip_finaldelimpat, 'e')
endfunction

" main function, called on press of <C-j> (or whatever key minisnip is bound to)
function! minisnip#minisnip() abort
    if exists('s:snippetfile')
        " reset placeholder text history (for backrefs)
        let s:placeholder_texts = []
        let s:placeholder_text = ''
        " adjust the indentation, use the current line as reference
        let l:ws = matchstr(getline(line('.')), '^\s\+')
        let l:lns = map(readfile(s:snippetfile), 'empty(v:val)? v:val : l:ws.v:val')

        " remove the snippet keyword
        " go to the position at the beginning of the snippet
        execute ':normal! '.(s:begcol - strchars(s:cword)).'|'
        " delete the snippet
        execute ':normal! '.strchars(s:cword).'"_x'

        if virtcol('.') >= (s:begcol - strchars(s:cword))
           " there is something following the snippet
           let l:keepEndOfLine = 1
           let l:endOfLine = strpart(getline(line('.')), (col('.') - 1))
           normal! "_D
        else
           let l:keepEndOfLine = 0
        endif

        " insert the snippet
        call append(line('.'), l:lns)

        if l:keepEndOfLine == 1
           " add the end of the line after the snippet
           execute ':normal! ' . len(l:lns) . 'j'
           call append((line('.')), l:endOfLine)
           join!
           execute ':normal! ' . len(l:lns) . 'k'
        endif

        if strchars(l:ws) > 0
           " remove the padding of the first line of the snippet
           execute ':normal! j0' . strchars(l:ws) . '"_xk$'
        endif
        join!

        " go to the beginning of the snippet
        execute ':normal! '.(s:begcol - strchars(s:cword)).'|'

        " select the first placeholder
        call s:SelectPlaceholder()
    else
        " Make sure '< mark is set so the normal command won't error out.
        if getpos("'<") == [0, 0, 0, 0]
            call setpos("'<", getpos('.'))
        endif

        " save the current placeholder's text so we can backref it
        let l:old_s = @s
        normal! ms"syv`<`s
        let s:placeholder_text = @s
        let @s = l:old_s
        " jump to the next placeholder
        call s:SelectPlaceholder()
    endif
endfunction

" this is the function that finds and selects the next placeholder
function! s:SelectPlaceholder() abort
    " don't clobber s register
    let l:old_s = @s

    " get the contents of the placeholder
    " we use /e here in case the cursor is already on it (which occurs ex.
    "   when a snippet begins with a placeholder)
    " we also use keeppatterns to avoid clobbering the search history /
    "   highlighting all the other placeholders
    try
        " gn misbehaves when 'wrapscan' isn't set (see vim's #1683)
        let [l:ws, &wrapscan] = [&wrapscan, 1]
        silent keeppatterns execute 'normal! /' . g:minisnip_delimpat . "/e\<cr>gn\"sy"
        " save length of entire placeholder for reference later
        let l:slen = len(@s)
        " remove the start and end delimiters
        let @s=substitute(@s, '\V' . g:minisnip_startdelim, '', '')
        let @s=substitute(@s, '\V' . g:minisnip_enddelim, '', '')
    catch /E486:/
         " There's no normal placeholder at all
        try
            silent keeppatterns execute 'normal! /' . g:minisnip_finaldelimpat . "/e\<cr>gn\"sy"
            " save length of entire placeholder for reference later
            let l:slen = len(@s)
            " remove the start and end delimiters
            let @s=substitute(@s, '\V' . g:minisnip_finalstartdelim, '', '')
            let @s=substitute(@s, '\V' . g:minisnip_finalenddelim, '', '')
        catch /E486:/
            " There's no placeholder at all, enter insert mode
            call feedkeys('A', 'n')
            return
        finally
            let &wrapscan = l:ws
            unlet! s:minisnip_selected_text
        endtry
    finally
        let &wrapscan = l:ws
    endtry

    " save the contents of the previous placeholder (for backrefs)
    call add(s:placeholder_texts, s:placeholder_text)

    if @s =~ '\V\^' . g:minisnip_evalmarker
       let l:skip = 1
    elseif @s =~ '\V\^' . g:minisnip_donotskipmarker . g:minisnip_evalmarker
       let @s=substitute(@s, '\V\^' . g:minisnip_donotskipmarker , '', '')
       let l:skip = 0
    else
       let l:skip = 0
    endif

    " is this placeholder marked as 'visual'?
    if @s =~ '\V\^' . g:minisnip_visualmarker
        " remove the marker
        let @s=substitute(@s, '\V\^' . g:minisnip_visualmarker, '', '')
        if exists('s:minisnip_selected_text')
            " get the text
            let @s=s:minisnip_selected_text
        endif
        let l:visualmarker = 1
        let l:skip = 1
    else
        let l:visualmarker = 0
    endif

    " is this placeholder marked as 'evaluate'?
    if @s =~ '\V\^' . g:minisnip_evalmarker
        " remove the marker
        let @s=substitute(@s, '\V\^' . g:minisnip_evalmarker, '', '')
        " substitute in any backrefs
        let @s=substitute(@s, '\V' . g:minisnip_backrefmarker . '\(\d\)',
            \"\\=\"'\" . substitute(get(
            \    s:placeholder_texts,
            \    len(s:placeholder_texts) - str2nr(submatch(1)), ''
            \), \"'\", \"''\", 'g') . \"'\"", 'g')
        " evaluate what's left
        let @s=eval(@s)
    endif

    if empty(@s)
        " the placeholder was empty, so just enter insert mode directly
        normal! gv"_d
        call feedkeys(col("'>") - l:slen >= col('$') - 1 ? 'a' : 'i', 'n')
    elseif l:skip == 1
       normal! gv"sp
       if l:visualmarker == 1
           " if the text came by replacing a visual marker, indent the same
           normal! gv=`]
       endif
       let @s = l:old_s
       call s:SelectPlaceholder()
    else
        " paste the placeholder's default value in and enter select mode on it
        execute "normal! gv\"spgv\<C-g>"
    endif

    " restore old value of s register
    let @s = l:old_s
endfunction

" function to get the selected text in a variable
function! minisnip#CopyVisualSelection() abort
    execute "'<,'>d"
    let s:minisnip_selected_text = substitute(@", '\n\+$', '', '')
    execute "normal! O\<Space>\<BS>\<Esc>"
    startinsert!
endfunction

function! minisnip#SetupPairs(var) abort
    for l:key in keys(a:var)
        let l:value = a:var[l:key]
        execute "inoremap " . l:key . " " . l:key . l:value . "<++>" . "\<C-\><C-o>5h"
        execute "inoremap <expr> " . l:value . " minisnip#BypassPair(\"" . l:value . "\")"
    endfor
endfunction

function! minisnip#BypassPair(value) abort
    let l:next_char = getline('.')[col('.')-1]
    if l:next_char == a:value
        if strcharpart(getline('.'), col('.'), 4) == "<++>"
            return "\<Right>\<C-\>\<C-o>4x"
        else
            return "\<Right>"
        endif
    else
        return a:value
    endif
endfunction

function! minisnip#BackSpace() abort
    let cur_line = getline('.')
    let before_char = cur_line[col('.')-2]
    let after_char = cur_line[col('.')-1]
    for l:key in keys(g:minisnip_pairs)
        let l:value = g:minisnip_pairs[l:key]
        if before_char == l:key && after_char == l:value
            if strcharpart(getline('.'), col('.'), 4) == "<++>"
                return "\<Left>\<C-\>\<C-o>6x"
            else
                return "\<Del>\<BS>"
            endif
        endif
    endfor
    return "\<BS>"
endfunction

function! minisnip#CarriageReturn() abort
    if pumvisible()
        return "\<C-y>"
    endif
    let cur_line = getline('.')
    let before_char = cur_line[col('.')-2]
    let after_char = cur_line[col('.')-1]
    for l:key in keys(g:minisnip_pairs)
        let l:value = g:minisnip_pairs[l:key]
        if before_char == l:key && after_char == l:value
            if strcharpart(getline('.'), col('.'), 4) == "<++>"
                return "\<CR>\<Right>\<C-o>4x\<Esc>O"
            else
                return "\<CR>\<C-o>O"
            endif
        endif
    endfor
    return "\<CR>"
endfunction

function! minisnip#RemovePlaceHoldersAndJumpToEnd() abort
    call setline(line("."), substitute(getline("."), '<++>', '', "g"))
    startinsert!
endfunction

function! minisnip#RemovePlaceHoldersAndStay() abort
    call setline(line("."), substitute(getline("."), '<++>', '', "g"))
    normal! l
    startinsert
endfunction

" Get the path separator for this platform.
function! s:pathsep()
    for l:w in ['win16', 'win32', 'win64', 'win95']
        if has(l:w)
            return ';'
        endif
    endfor
    return ':'
endfunction
