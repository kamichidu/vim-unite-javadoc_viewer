" ----------------------------------------------------------------------------
" File:        autoload/unite/sources/javadoc_viewer.vim
" Last Change: 31-Aug-2013.
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
unlet s:V

let s:source= {
\   'name'           : 'javadoc_viewer',
\   'description'    : 'a javadoc viewer using unite.',
\   'sorters'        : ['sorter_word'],
\   'max_candidates' : 100,
\   'hooks'          : {}, 
\}
function! unite#sources#javadoc_viewer#define() " {{{
    return s:source
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

    let l:success= 0

    perl << EOQ
    use strict;
    use warnings;
    use URI;
    use Web::Scraper;
    use JSON::PP;

    my $uri= eval {
        my @uri= VIM::Eval('l:uri');

        die q/can't get vim variable in if_perl./ unless $uri[0];

        URI->new($uri[1]);
    };
    die $@ if $@;

    my $res= scraper {
        process 'div.indexContainer li>a[href]', 'links[]' => '@href';
    }->scrape(URI->new_abs('allclasses-noframe.html', $uri));

    my @result= map {
        my $link= $_;

        # link -> canonical_name
        my $canonical_name= URI->new($link)->rel($uri);

        $canonical_name=~ s{/}{.}g;
        $canonical_name=~ s{\.html$}{};

        {
            word => $canonical_name, 
            action__uri => $link->as_string, 
        }
    } @{$res->{links}};

    VIM::DoCommand('let l:candidates= ' . encode_json(\@result));
    VIM::DoCommand('let l:success= 1');
EOQ
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

