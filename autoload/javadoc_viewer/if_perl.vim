" ----------------------------------------------------------------------------
" File:        autoload/javadoc_viewer/if_perl.vim
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

function! javadoc_viewer#if_perl#gather_candidates(uri)
    perl << EOQ
    use strict;
    use warnings;
    use URI;
    use Web::Scraper;
    use JSON::PP;

    my $uri= eval {
        my @uri= VIM::Eval('a:uri');

        die q/can't get vim variable in if_perl./ unless $uri[0];

        URI->new($uri[1]);
    };
    die $@ if $@;

    my $res= scraper {
        process 'a[href]', 'links[]' => '@href';
    }->scrape(URI->new_abs('allclasses-noframe.html', $uri));

    my @result= sort { $a->{abbr} cmp $b->{abbr} } map {
        my $link= $_;

        # link -> canonical_name
        my $canonical_name= URI->new($link)->rel($uri);

        $canonical_name=~ s{/}{.}g;
        $canonical_name=~ s{\.html$}{};

        {
            word => $link->as_string, 
            abbr => $canonical_name, 
            kind => 'uri', 
            action__path => $link->as_string, 
        }
    } @{$res->{links}};

    VIM::DoCommand('let l:candidates= ' . encode_json(\@result));
    VIM::DoCommand('let l:success= 1');
EOQ
    return [l:success, l:candidates]
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo

" vim:foldenable:foldmethod=marker

