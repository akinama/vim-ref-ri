if !exists('g:ref_ri_cmd')
  let g:ref_ri_cmd = executable('ri') ? 'ri' : ''
endif
let s:cmd = g:ref_ri_cmd

" source definition {{{1

let s:source = {'name': 'ri'}

function! s:source.available() " {{{2
  return !empty(g:ref_ri_cmd)
endfunction

function! s:source.get_body(query) " {{{2
  let res = s:ri(a:query)
  if res.stderr != ''
    throw res.stderr
  endif
  return res.stdout
endfunction

function! s:source.opened(query) " {{{2
  call s:syntax()
endfunction

function! s:source.get_keyword() " {{{2
  let id = '\v\w+[!?]?'
  let pos = getpos('.')[1:]

  if &l:filetype ==# 'ref-ri'
    let [type, name] = s:detect_type()
    if type ==# 'class'
      let kwd = ref#get_text_on_cursor('\S\+[!?]\{0,1}')
      if kwd != ''
        return name . '.' . kwd
      end
    endif
  endif
  return expand('<cword>')
endfunction

function! s:source.complete(query) " {{{2
  return split(s:ri('').stdout, "\n")
endfunction

function! ref#ri#define() " {{{2
  return copy(s:source)
endfunction

call ref#register_detection('ruby', 'ri')

" syntax highlight {{{1
function! s:syntax() "
  command! -nargs=+ HtmlHiLink highlight def link <args>

  syntax clear

  syntax spell toplevel
  syntax case ignore
  syntax sync linebreaks=1

  " RDoc text markup
  syntax region rdocBold      start=/\\\@<!\(^\|\A\)\@=\*\(\s\|\W\)\@!\(\a\{1,}\s\|$\n\)\@!/ skip=/\\\*/ end=/\*\($\|\A\|\s\|\n\)\@=/ contains=@Spell
  syntax region rdocEmphasis  start=/\\\@<!\(^\|\A\)\@=_\(\s\|\W\)\@!\(\a\{1,}\s\|$\n\)\@!/  skip=/\\_/  end=/_\($\|\A\|\s\|\n\)\@=/  contains=@Spell
  "syntax region rdocMonospace start=/\\\@<!\(^\|\A\)\@=+\(\s\|\W\)\@!\(\a\{1,}\s\|$\n\)\@!/  skip=/\\+/  end=/+\($\|\A\|\s\|\n\)\@=/  contains=@Spell

  " RDoc links: {link}[URL]
  syntax region rdocLink matchgroup=rdocDelimiter start="\!\?{" end="}\ze\s*[\[\]]" contains=@Spell nextgroup=rdocURL,rdocID skipwhite oneline
  syntax region rdocID   matchgroup=rdocDelimiter start="{"     end="}"  contained
  syntax region rdocURL  matchgroup=rdocDelimiter start="\["    end="\]" contained
  " RDoc inline links:           protocol   optional  user:pass@       sub/domain                 .com, .co.uk, etc      optional port   path/querystring/hash fragment
  "                            ------------ _____________________ --------------------------- ________________________ ----------------- __
  syntax match  rdocInlineURL /https\?:\/\/\(\w\+\(:\w\+\)\?@\)\?\([A-Za-z][-_0-9A-Za-z]*\.\)\{1,}\(\w\{2,}\.\?\)\{1,}\(:[0-9]\{1,5}\)\?\S*/

  " Define RDoc markup groups
  syntax match  rdocLineContinue ".$" contained
  syntax match  rdocRule      /^\s*\*\s\{0,1}\*\s\{0,1}\*$/
  syntax match  rdocRule      /^\s*-\s\{0,1}-\s\{0,1}-$/
  syntax match  rdocRule      /^\s*_\s\{0,1}_\s\{0,1}_$/
  syntax match  rdocRule      /^\s*-\{3,}$/
  syntax match  rdocRule      /^\s*\*\{3,5}$/
  syntax match  rdocListItem  "^\s*[-*+]\s\+"
  syntax match  rdocListItem  "^\s*\d\+\.\s\+"
  syntax match  rdocLineBreak /  \+$/

  " RDoc pre-formatted markup
  " syntax region rdocCode      start=/\s*``[^`]*/          end=/[^`]*``\s*/
  syntax match  rdocCode  /^\s*\n\(\(\s\{1,}[^ ]\|\t\+[^\t]\).*\n\)\+/
  syntax region rdocCode  start="<em[^>]*>"   end="</em>"
  syntax region rdocCode  start="<tt[^>]*>"   end="</tt>"
  syntax region rdocCode  start="<pre[^>]*>"  end="</pre>"
  syntax region rdocCode  start="<code[^>]*>" end="</code>"

  " RDoc HTML headings
  syntax region htmlH1  start="^\s*="       end="\($\)" contains=@Spell
  syntax region htmlH2  start="^\s*=="      end="\($\)" contains=@Spell
  syntax region htmlH3  start="^\s*==="     end="\($\)" contains=@Spell
  syntax region htmlH4  start="^\s*===="    end="\($\)" contains=@Spell
  syntax region htmlH5  start="^\s*====="   end="\($\)" contains=@Spell
  syntax region htmlH6  start="^\s*======"  end="\($\)" contains=@Spell

  " Highlighting for RDoc groups
  HtmlHiLink rdocCode         String
  HtmlHiLink rdocLineContinue Comment
  HtmlHiLink rdocListItem     Identifier
  HtmlHiLink rdocRule         Identifier
  HtmlHiLink rdocLineBreak    Todo
  HtmlHiLink rdocLink         htmlLink
  HtmlHiLink rdocInlineURL    htmlLink
  HtmlHiLink rdocURL          htmlString
  HtmlHiLink rdocID           Identifier
  HtmlHiLink rdocBold         htmlBold
  HtmlHiLink rdocEmphasis     htmlItalic
  "HtmlHiLink rdocMonospace    String

  HtmlHiLink htmlH1           Title
  HtmlHiLink htmlH2           htmlH1
  HtmlHiLink htmlH3           htmlH2
  HtmlHiLink htmlH4           htmlH3
  HtmlHiLink htmlH5           htmlH4
  HtmlHiLink htmlH6           htmlH5

  HtmlHiLink rdocDelimiter    Delimiter

  delcommand HtmlHiLink
endfunction

" functions {{{1
" detect_type {{{2
" Detect the reference type from content.
" - ['list', ''] (Matched list)
" - ['class' class_name] (Summary of class)
" - ['method', class_and_method_name] (Detail of method)
function! s:detect_type()
  let line = getline(1)
  if stridx(line, '<') >= 0
    let name = matchstr(line, '^= \zs[^ ]\+\ze')
    return ['class', name]
  endif
  return ['list', '']
endfunction

function! s:ri(args) " {{{2
  return ref#system(ref#to_list(g:ref_ri_cmd, '--format=rdoc') + ref#to_list(a:args))
endfunction

" vim: foldmethod=marker
