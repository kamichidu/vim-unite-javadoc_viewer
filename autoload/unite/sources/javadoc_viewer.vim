" ----------------------------------------------------------------------------
" File:        autoload/unite/sources/javadoc_viewer.vim
" Last Change: 05-Sep-2013.
" Maintainer:  kamichidu <c.kamunagi@gmail.com>
" License:     The MIT License (MIT) {{{
" 
"              Copyright (c) 2013 kamichidu
"
"              Permission is hereby granted, free of charge, to any person
"              obtaining a copy of this software and associated documentation
"              files (the "Software"), to deal in the Software without
"              restriction, including without limitation the rights to use,
"              copy, modify, merge, publish, distribute, sublicense, and/or
"              sell copies of the Software, and to permit persons to whom the
"              Software is furnished to do so, subject to the following
"              conditions:
"
"              The above copyright notice and this permission notice shall be
"              included in all copies or substantial portions of the Software.
"
"              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
"              EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
"              OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
"              NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
"              HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
"              WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
"              FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
"              OTHER DEALINGS IN THE SOFTWARE.
" }}}
" ----------------------------------------------------------------------------
let s:save_cpo= &cpo
set cpo&vim

let s:V= vital#of('unite-javadoc_viewer')
let s:L= s:V.import('Data.List')
let s:C= s:V.import('System.Cache')
let s:H= s:V.import('Web.HTTP')
let s:BM= s:V.import('Vim.BufferManager').new()
unlet s:V

let s:source= {
\   'name':           'javadoc_viewer',
\   'description':    'a javadoc viewer using unite.',
\   'sorters':        ['sorter_nothing'],
\   'max_candidates': 100,
\   'hooks':          {},
\   'action_table':   {
\       'uri': {
\           'show': {
\               'description': 'print the javadoc on the preview window.', 
\               'is_quit':     0, 
\           }, 
\       }, 
\   }, 
\   'default_action': {'uri': 'show'}, 
\}
function! unite#sources#javadoc_viewer#define() " {{{
    if has('perl')
        return s:source
    else
        return {}
    endif
endfunction
" }}}

function! s:source.gather_candidates(args, context) " {{{
    call s:check_config()

    let a:context.source__rest_uris= deepcopy(g:javadocviewer_config.uri)
    let a:context.source__cache_dir= deepcopy(g:javadocviewer_config.cache_dir)

    let a:context.is_async= 1

    return []
endfunction
" }}}

function! s:source.async_gather_candidates(args, context) " {{{
    if empty(a:context.source__rest_uris)
        let a:context.is_async= 0
        return []
    endif

    let l:uri= s:L.shift(a:context.source__rest_uris)

    " check cache
    if s:C.filereadable(a:context.source__cache_dir, l:uri)
        let l:candidates= s:C.readfile(a:context.source__cache_dir, l:uri)

        return map(l:candidates, 'eval(v:val)')
    endif

    let [l:success, l:candidates]= javadoc_viewer#if_perl#gather_candidates(l:uri)

    if l:success
        if s:C.check_old_cache(a:context.source__cache_dir, l:uri)
            call s:C.deletefile(a:context.source__cache_dir, l:uri)
        endif

        call s:C.writefile(a:context.source__cache_dir, l:uri, map(deepcopy(l:candidates), 'string(v:val)'))

        return l:candidates
    else
        return []
    endif
endfunction
" }}}

" show javadoc
function! s:source.action_table.uri.show.func(candidate) " {{{
    if empty(a:candidate.action__path)
        return
    endif

    let l:response= s:H.get(a:candidate.action__path)
    if !l:response.success
        return
    endif

    " TODO get formatter name from candidate?
    let l:formatter= g:javadocviewer_config.formatter
    let l:text= javadoc_viewer#formatter#{l:formatter}#format(l:response.content)

    let l:bufname= 'javadocviewer - ' . a:candidate.action__canonical_name
    call s:BM.open(l:bufname)
    setlocal bufhidden=hide buftype=nofile noswapfile nobuflisted readonly
    let &l:filetype= 'javadocviewer'
    silent % delete _
    silent 0 put =l:text
    call cursor(1, 1)
endfunction
" }}}

function! s:check_config() " {{{
    if !(exists('g:javadocviewer_config') && type(g:javadocviewer_config) == type({}))
        throw s:make_message('g:javadocviewer_config is not exists or not a dictionary.')
    elseif !has_key(g:javadocviewer_config, 'uri')
        throw s:make_message('g:javadocviewer_config.uri is not exists.')
    elseif !has_key(g:javadocviewer_config, 'cache_dir')
        throw s:make_message('g:javadocviewer_config.cache_dir is not exists.')
    endif
endfunction
" }}}

function! s:make_message(message) " {{{
    return 'javadocviewer: ' . string(a:message)
endfunction
" }}}

let &cpo= s:save_cpo
unlet s:save_cpo

" vim:foldenable:foldmethod=marker

