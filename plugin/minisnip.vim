if exists('g:loaded_minisnip')
    finish
endif
let g:loaded_minisnip = 1

" set default global variable values
let g:minisnip_dir = '~/.vim/snippets'
let g:minisnip_trigger = '<C-j>'
let g:minisnip_startdelim = '<+'
let g:minisnip_enddelim = '+>'
let g:minisnip_finalstartdelim = '<-'
let g:minisnip_finalenddelim = '->'
let g:minisnip_evalmarker = '~'
let g:minisnip_visualmarker = '~#'
let g:minisnip_donotskipmarker = '`'
let g:minisnip_backrefmarker = '\\~'

" this is the pattern used to find placeholders
let g:minisnip_delimpat = '\V' . g:minisnip_startdelim . '\.\{-}' . g:minisnip_enddelim

" this is the pattern used to find final placeholders
let g:minisnip_finaldelimpat = '\V' . g:minisnip_finalstartdelim . '\.\{-}' . g:minisnip_finalenddelim

let g:minisnip_pairs = {'(': ')', '{': '}', '[': ']'}

" plug mappings
" the eval/escape charade is to convert ex. <Tab> into a literal tab, first
" making it \<Tab> and then eval'ing that surrounded by double quotes
inoremap <script> <expr> <Plug>(minisnip) minisnip#ShouldTrigger() ?
            \"x\<BS>\<esc>:call \minisnip#minisnip()\<CR>" :
            \eval('"' . escape(g:minisnip_trigger, '\"<') . '"')
snoremap <script> <expr> <Plug>(minisnip) minisnip#ShouldTrigger() ?
            \"\<Esc>:call \minisnip#minisnip()\<CR>" :
            \eval('"' . escape(g:minisnip_trigger, '\"<') . '"')
xnoremap <silent> <Plug>(minisnip-visual) :<C-u>call minisnip#CopyVisualSelection()<CR>

execute 'imap <unique> ' . g:minisnip_trigger . ' <Plug>(minisnip)'
execute 'smap <unique> ' . g:minisnip_trigger . ' <Plug>(minisnip)'
execute 'xmap <unique> ' . g:minisnip_trigger . ' <Plug>(minisnip-visual)'

inoremap <silent> <C-l> <C-c>:<C-u>call minisnip#RemovePlaceHoldersAndJumpToEnd()<CR>
inoremap <silent> <C-k> <C-c>:<C-u>call minisnip#RemovePlaceHoldersAndStay()<CR>

inoremap <silent> <BS> <C-r>=minisnip#BackSpace()<CR>
inoremap <silent> <CR> <C-r>=minisnip#CarriageReturn()<CR>

call minisnip#SetupPairs(g:minisnip_pairs)
