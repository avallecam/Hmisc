html <- function(object, ...) UseMethod('html')

html.latex <- function(object, file, where=c('cwd', 'tmp'),
                       method=c('hevea', 'htlatex'), rmarkdown=FALSE,
                       cleanup=TRUE, ...)
{
  where  <- match.arg(where)
  method <- match.arg(method)
  if(where == 'tmp') cleanup <- FALSE
  if(rmarkdown && ! missing(file))
    warning('do not specify file when rmarkdown=TRUE')
  fi  <- object$file
  fibase <- gsub('\\.tex', '', fi)
  if(missing(file)) file <- paste(fibase, 'html', sep='.')
  if(rmarkdown) file <- character(0)
  toConsole <- ! length(file) || file == ''

  ehtml = function(content) {   # Thanks to Yihui
    if(! requireNamespace('htmltools', quietly=TRUE))
      stop('htmltools package not installed')
    
    content = htmltools::HTML(gsub('^.*?<body\\s*>|</body>.*$', '', content))
    ss  <- paste(fibase, '-enclosed.css', sep='')
    src <- switch(where, cwd=getwd(), tmp=tempdir())
    d = htmltools::htmlDependency(
      'TeX4ht', '1.0.0', src = src, stylesheet = ss)
    htmltools::attachDependencies(content, d)
  }
  
  sty <- object$style
  if(length(sty))
    sty <- paste('\\usepackage{', unique(sty), '}', sep='')

  tmp    <- switch(where,
                   cwd = paste(fibase, 'enclosed', sep='-'),
                   tmp = tempfile())
  tmptex <- paste(tmp, 'tex', sep='.')
  infi   <- readLines(fi)

  cat('\\documentclass{report}', sty,
      if(method == 'hevea') '\\def\\tabularnewline{\\\\}',
      '\\begin{document}', infi,
      '\\end{document}\n', file=tmptex, sep='\n')
  sc <- if(.Platform$OS.type == 'unix') ';' else '&'

  ## Create system call to convert enclosed latex file to html.
  cmd <-
    if(missing(file) || ! length(file) || file == '') 
      paste(optionsCmds(method), shQuote(tmptex))
    else 
      paste(optionsCmds(method), '-o', file, shQuote(tmptex))
    
  ## perform system call
  sys(cmd)

  if(method == 'hevea' && ! toConsole) {
    ## Remove 2 bottom lines added by HeVeA
    infi <- readLines(file)
    i <- grep('<hr style="height:2"><blockquote class="quote"><em>This document was translated from L<sup>A</sup>T<sub>E</sub>X by', infi)
    i <- c(i, grep('</em><a href="http://hevea.inria.fr/index.html"><em>H</em><em><span style="font-size:small"><sup>E</sup></span></em><em>V</em><em><span style="font-size:small"><sup>E</sup></span></em><em>A</em></a><em>.</em></blockquote></body>', infi))
    if(length(i)) {
      infi <- infi[- i]
      writeLines(infi, file)
    }
    if(cleanup) {
      bf <- gsub('\\.html', '', file)
      unlink(c(paste(bf, 'haux', sep='.'),
               paste(bf, 'enclosed.tex', sep='-')))
    }
    return(structure(list(file=file), class='html'))
    
  }

  if(cleanup && method == 'htlatex')
    unlink(paste(tmp, c('tex', 'tmp','idv','lg','4tc','aux','dvi','log',
                        'xref','4ct'), sep='.'))
  if(rmarkdown || toConsole) {
    w <- readLines(paste(tmp, 'html', sep='.'))
    if(rmarkdown) return(ehtml(w))
    if(! length(file)) return(paste(w, collapse='\n'))
    cat(w, sep='\n')
    return(invisible())
  }

  structure(list(file=file), class='html')
}


html.data.frame <-
  function(object,
           file=paste(first.word(deparse(substitute(object))),
                      'html',sep='.'),
           header,
           align='r', align.header='c', bold.header=TRUE,
           col.header='Black', border=2,
           size=100, translate=FALSE,
           append=FALSE, link=NULL, linkCol=1,
           linkType=c('href','name'), ...)
{
  linkType <- match.arg(linkType)
  
  align <- switch(align,
                  c='center',
                  l='left',
                  r='right')
  align.header <- switch(align.header,
                         c='center',
                         l='left',
                         r='right')
  trans <- if(translate) htmlTranslate else function(x) x
  
  x   <- as.matrix(object)
  for(i in 1:ncol(x)) {
    xi <- x[,i]
#    if(is.numeric(object[,i]))
#      x[,i] <- paste0('<div align=right>', xi, '</div>')
  }
  if(length(r <- rownames(x)))
    x <- cbind(Name=as.character(r), x)

  b <- c('border: 1px solid gray;', 'border-collapse: collapse;')
  ## Give style a name hmisctablexxx where xxx is a random 6-digit integer
  ## because if you reuse the same style in the same document, style
  ## elements will affect tables that preceeded this one
  sn  <- paste0('hmisctable', floor(runif(1, 100000, 999999)))
  psn <- paste0('.', sn)
  
  # Duplicate specifications because can't get any single one to work
  sty <- c('<style>',
           paste0(psn, ' {'),
           if(border == 0) 'border: none;' else b,
           paste0('font-size: ', size, '%;'),
           '}',
           paste0(psn, ' td {'),
           paste0('text-align: ', align, ';'),
           'padding: 0 1ex 0 1ex;',   ## top left bottom right
           '}',
           paste0(psn, ' th {'),
           paste0('color: ', col.header, ';'),
           paste0('text-align: ', align.header, ';'),
           'padding: 0 1ex 0 1ex;',
           if(bold.header) 'font-weight: bold;' else 'font-weight: normal;',
           '}',
           '</style>')
          
  R <- c(sty, paste0('<table class="', sn, '"',
                     if(border == 1) 'border="0"',
                     if(border == 2) 'border="1"', '>'))
  if(missing(header)) header <- colnames(x)
  if(length(header)) {
    head <- trans(header)
    head <- paste0('<th>', head, '</th>')
    head <- paste0('<tr>', paste(head, collapse=''), '</tr>')
    R <- c(R, head)
    }
  
  if(length(link)) {
    if(is.matrix(link)) 
      x[link != ''] <- paste0('<a ',linkType,'="', link[link!=''],'">',
                              trans(x[link != '']), '</a>')
    else
      x[,linkCol] <- ifelse(link == '', trans(x[, linkCol]),
                            paste0('<a ',linkType,'="',link,'">',
                                   trans(x[, linkCol]),'</a>'))
  }

  for(i in 1 : nrow(x)) {
    rowt <- paste0('<td>', x[i, ], '</td>')
    R <- c(R, paste0('<tr>', paste(rowt, collapse=''), '</tr>'))
    }

  R <- c(R, '</table>')
  if(is.logical(file) && ! file)
    return(htmltools::HTML(paste0(R, '\n')))

  cat(R, file=file, append=append && file != '', sep='\n')
  structure(list(file=file), class='html')
}


html.default <- function(object,
                         file=paste(first.word(deparse(substitute(object))),
                                    'html', sep='.'),
                         append=FALSE,
                         link=NULL, linkCol=1, linkType=c('href','name'),
                         ...)
  html.data.frame(object, file=file, append=append, link=link,
                  linkCol=linkCol, linkType=linkType, ...)


if(FALSE) {
  show.html <- function(object)
  {
    browser <- .Options$help.browser
    if(!length(browser))
      browser <- .Options$browser
    
    if(!length(browser))
      browser <- 'netscape'
    
    sys(paste(browser, object, if(.Platform$OS.type == 'unix') '&'))
    invisible()
  }
  
  print.html <- function(x, ...) show.html(x)
}


htmlVerbatim <- function(..., size = 75, width = 85,
                         scroll=FALSE, rows=10, cols=100) {
  if(scroll) {
    nam <- as.character(sys.call()[2])
    w <- paste0('<textarea class="scrollabletextbox" rows=', rows,
                ' cols=', cols, ' style="font-size:', size,
                '%; font-family:Courier New;" name="', nam, '">')
    }
  else w <- paste0('<pre style="font-size:', size, '%;">')
  op <- options(width=width)
  for(x in list(...)) w <- c(w, capture.output(print(x)))
  options(op)
  w <- c(w, if(scroll) '</textarea>' else '</pre>')
  w <- paste0(w, '\n')
  htmltools::HTML(w)
}


markupSpecs <- list(html=list(
  bold     = function(x) paste0('<strong>', x, '</strong>'),
  italics  = function(x) paste0('<i>', x, '</i>'),
  math     = function(x) paste0('<i>', x, '</i>'),
  code     = function(x) paste0('<code style="font-size:0.8em">', x, '</code>'),
  sup      = function(x, ...) paste0('<sup>', x, '</sup>'),
  sub      = function(x, ...) paste0('<sub>', x, '</sub>'),
  size     = function(x, pct) paste0('<span style="font-size: ', pct,
                                     '%;">', paste(x, collapse=' '),
                                     '</span>'),
  smaller  = function(x) paste0('<span style="font-size: 80%;">', x,
                                '</span>'),
  larger   = function(x) paste0('<span stype="font-size: 125%;">', x,
                                '</span>'),
  smaller2 = function(x) paste0('<span style="font-size: 64%;">', x,
                                 '</span>'),
  larger2  = function(x) paste0('<span style="font-size: 156%;">', x,
                                 '</span>'),
  center   = function(x) paste0('<div align=center>', x, '</div>'),
  subtext  = function(..., color='blue')
    paste0('<br><font size=1 color="', color, '">',
           paste(unlist(list(...)), collapse=' '),
           '</font>'),
  session  = function(cite=TRUE, loadedOnly=FALSE) {
    si <- sessionInfo()
    if(! loadedOnly) si$loadedOnly <- NULL
    w <- c('<pre>',
           capture.output(print(si, locale=FALSE)),
           '</pre>',
           if(cite) 'To cite R in publication use:',
           if(cite) capture.output(print(citation(), style='html')))
    w <- paste0(w, '\n')
    htmltools::HTML(w)
  },
  installcsl = function(cslname, rec=FALSE) {
    if(rec) {
      cat('Shows URLs:', 'american-medical-association',
                '',
                'Does not show URLs:', 'council-of-science-editors',
          'american-medical-association-no-url', sep='\n')
      return(invisible())
      }
    if(missing(cslname))
      browseURL('https://www.zotero.org/styles')
    else
      download.file(paste0('https://raw.githubusercontent.com/citation-style-language/styles/master/',
                           cslname, '.csl'), paste0(cslname, '.csl'))
  },
  citeulikeShow = function(user, bibkeys=NULL, tags=NULL, file=NULL) {
    if(length(file)) {
      x <- readLines(file)
      ## See http://stackoverflow.com/questions/8613237
      bibkeys <- unlist(regmatches(x, gregexpr("(?<=\\[@).*?(?=\\])",
                                               x, perl=TRUE)))
      }
    if(length(bibkeys)) {
      keys <- paste(paste0('bibkey%3A+', bibkeys), collapse='+OR+')
      browseURL(paste0('http://www.citeulike.org/search/username?q=',
                       keys, '&search=Search+library&username=', user))
    } else browseURL(paste0('http://www.citeulike.org/user/',
                            user, '/tag/', tags))
    invisible(bibkeys)
    },
  widescreen = function(width='4000px')
    htmltools::HTML(paste0('<style>div.main-container {max-width:',
                           width, ';}</style>')),
  tocsize = function(width = '20%', maxwidth = '260px', maxheight='85%')
    htmltools::HTML(paste0('<style>div.tocify {width: ', width,
                           '; max-width: ', maxwidth, '; max-height: ',
                           maxheight, ';}</style>')),
  scroll   = function(x, size=75, rows=10, cols=100,
                      font='', name='') {
    w <- paste0('<div style="width: ', cols, 'ex; overflow: auto; height: ',
                rows, 'ex;">')
    c(w, x, '</div>')
    },
  chisq    = function(x, ...)
#    paste0('&chi;<span class="xscript" style="font-size: 75%;"><sup>2</sup><sub>', x,
#           '</sub></span>')
                 if(missing(x)) paste0('&chi;<sup>2</sup>')
                 else
                   paste0("&chi;", markupSpecs$html$subsup(x, '2')),
  fstat    = function(x, ...) paste0('<i>F</i><sub><span style="font-size: 80%;">',
                                     x[1], ',&thinsp;', x[2], '</span></sub>'),
  frac     = function(a, b, size=82, ...)
    paste0('<span style="font-size: ', size, '%;"><sup>',
           a, '</sup>&frasl;<sub>', b, '</sub></span>'),
  subsup   = function(a, b) paste0("<sup><span style='font-size: 70%;'>", b,
                                   "</span></sup><sub style='position: relative; left: -.47em; bottom: -.4em;'><span style='font-size: 70%;'>",
                                   a, "</span></sub>"),
  varlabel = function(label, units='', size=75, hfill=FALSE) {
    if(units=='') label
    else
      if(hfill) paste0("<div style='float: left; text-align: left;'>", label,
                       "</div><div style='float: right; text-align: right; font-family: Verdana; font-size:", size, "%;'>", units, "</div>")
    else
      paste0(label,
             "&emsp;<span style='font-family:Verdana;font-size:", size, "%;'>",
             units, "</span>") },
  space    = '&nbsp;',
  lspace   = '&emsp;',
  sspace   = '&thinsp;',
  smallskip= '<br><br>',
  medskip  = '<br><br><br>',
  bigskip  = '<br><br><br><br>',
  lineskip = function(n) paste0('\n<p style="padding-top:', n, 'em;">'),
  br       = '<br>',
  hrule    = '<hr>',
  hrulethin= '<hr class="thinhr">',
  plminus  = '&plusmn;',
  times    = '&times;',
  xbar     = '<span style="text-decoration: overline">X</span>',
  styles   = '
<style>
hr.thinhr { margin-top: 0.15em; margin-bottom: 0.15em; }

span.xscript {
position: relative;
}
span.xscript sub {
position: absolute;
left: 0.1em;
bottom: -1ex;
}
</style>
'

),

latex = list(
  bold     = function(x) paste0('\\textbf{', x, '}'),
  italics  = function(x) paste0('\\emph{', x, '}'),
  math     = function(x) paste0('$', x, '$'),
  code     = function(x) paste0('\\texttt{\\smaller ', x, '}'),
  sup      = function(x, add='$') paste0(add, '^{',x, '}', add),
  sub      = function(x, add='$') paste0(add, '_{',x, '}', add),
  smaller  = function(x) paste0('{\\smaller ',     x, '}' ),
  larger   = function(x) paste0('{\\smaller[-1]{', x, '}' ),
  smaller2 = function(x) paste0('{\\smaller[2]{',  x, '}' ),
  larger2  = function(x) paste0('{\\smaller[-2]{', x, '}' ),
  center   = function(x) paste0('\\centerline{', x,   '}' ),
  chisq    = function(x, add='$') if(missing(x)) paste0(add, '\\chi^{2}', add)
                                  else paste0(add, '\\chi^{2}_{', x,    '}', add),
  fstat    = function(x, add='$')
    paste0(add, 'F_{', x[1], ',', x[2], '}', add),
  frac     = function(a, b, add='$', ...)
    paste0(add, '\\frac{', a, '}{', b, '}', add),
  subsup   = function(a, b) paste0('$_{', a, '}^{', b, '}$'),
  varlabel = function(label, units='', hfill=FALSE, ...) {
    if(units=='') return(label) else units <- latexTranslate(units)
    fill <- if(hfill) '~\\hfill' else '~~~'
    paste0(label, fill, '\\texttt{\\smaller[2] ',
           gsub('\\*', ' ', units), '}')
    },
  space    = '~',
  lspace   = '~~',
  sspace   = '\\,',
  smallskip= '\\smallskip',
  medskip  = '\\medskip',
  bigskip  = '\\bigskip',
  lineskip = function(n) paste0('\n\\vspace{', n, 'ex}\n\n'),
  br       = '\\\\',
  hrule    = '\\hrule',
  plminus  = '$\\pm$',
  times    = '$\\times$',
  xbar     = '$\\bar{X}$'
),

plain = list(
  space = ' ',
  lspace = '   ',
  sspace = ' ',
  br     = '\n',
  lineskip = function(n) paste(rep('\n', n), collapse=''),
  hrule  = '',
  code   = function(x) x,
  frac   = function(a, b, ...) paste0(a, '/', b),
  varlabel = function(label, units='', ...)
    if(units == '') label else  paste0(label, '  [', units, ']'),
  times  = 'x'
),

plotmath = list(
  varlabel = function(label, units='', ...)
    labelPlotmath(label, units)
  )
)

## Function to translate several expressions to html form.
## Arguments inn and out specify additional input and translated
## strings over the usual defaults.

htmlTranslate <- function(object, inn=NULL, out=NULL,
                           greek=FALSE, na='', ...)
{
  text <- ifelse(is.na(object), na, as.character(object))

  ## Must translate & first so won't be converted to &amp; when other
  ## symbols are translated
  inn <- c("&", "|",  "%",  "#",   "<=",     "<",  ">=",     ">",  "_", "\\243",
           "\\$", inn, c("[", "(", "]", ")"))

  out <- c("&amp;", "&#124;", "&#37", "&#35;", "&#8804;", "&#60;", "&#8805;",
           "&#62;", "&#95;",  "&pound;",
           "&dollar;", out, 
           c("&#91;", "&#40;", "&#93;", "&#41;"))

  ##See if string contains an ^ - superscript followed by a number

  dig <- c('0','1','2','3','4','5','6','7','8','9')

  for(i in 1 : length(text)) {
    lt <- nchar(text[i])
    x <- substring(text[i], 1 : lt, 1 : lt)
    j <- x == '^'
    if(any(j)) {
      is <- ((1 : lt)[j])[1]  #get first ^
      remain <- x[-(1 : is)]
      k <- remain %in% c(' ',',',')',']','\\','$')
      if(remain[1] %in% dig ||
         (length(remain) > 1 && remain[1] == '-' && remain[2] %in% dig))
        k[-1] <- k[-1] | remain[-1] %nin% dig
      
      ie <- if(any(k)) is + ((1 : length(remain))[k])[1]
        else
          length(x) + 1
      
      substring2(text[i], is, ie - 1) <-
        paste0('BEGINSUP', substring(text[i], is + 1, ie - 1), 'ENDSUP')
    }
    text[i] <- sedit(text[i], c(inn, '^', 'BEGINSUP', 'ENDSUP'),
                     c(out, '&#94;', '<sup>', '</sup>'), wild.literal=TRUE)

    if(greek) {
      gl <- c('alpha','beta','gamma','delta','epsilon','varepsilon',
              'zeta', 'eta',
              'theta','vartheta','iota','kappa','lambda','mu','nu',
              'xi','pi','varpi','rho','varrho','sigma','varsigma','tau',
              'upsilon','phi','carphi','chi','psi','omega','Gamma','Delta',
              'Theta','Lambda','Xi','Pi','Sigma','Upsilon','Phi','Psi','Omega')
      ## See http://stackoverflow.com/questions/22888646/making-gsub-only-replace-entire-words
      for(w in gl)
        text[i] <- gsub(paste0('\\<', w, '\\>'),
                        paste0('&', w, ';'), text[i])
    }
  }
  text
}
