# Copy to /tmp, and after running to create z.tex, run pdflatex

require(Hmisc)
x <- cbind(x1=1:5, x2=2:6)
file <- '/tmp/z.tex'
# Note: adding here package caused LaTeX problems
cat('\\documentclass{article}\n\\usepackage{hyperref,lscape,ctable,booktabs,longtable}\n\\begin{document}\n', file=file)

# Example from Johannes Hofrichter
dat <- data.frame(a=c(1,2), b=c(2,3))
w <- latex(dat, file=file, ctable=TRUE,
           caption = "caption", label="test", append=TRUE)

# Example from Ben Bolker
d <- data.frame(x=1:2,
                y=c(paste("a",
                    paste(rep("very",30),collapse=" "),"long string"),
                "a short string"))
w <- latex(d, file=file, col.just=c("l","p{3in}"), table.env=FALSE, append=TRUE)

# Example from Yacine H
df <- data.frame(matrix(1:16, ncol=4))
latex(df, file="", rownamesTexCmd="bfseries")
latex(df, file="", cgroup=c("G1","G2"), n.cgroup=c(2,2))
latex(df, file="", cgroup=c("G1","G2"), n.cgroup=c(2,2),
      rownamesTexCmd="bfseries")

## Test various permutations of options
test <- function(caption=NULL, center=NULL, table.env=TRUE, size=NULL,
                 booktabs=FALSE, landscape=FALSE, ctable=FALSE, longtable=FALSE,
                 hyperref=NULL, insert=TRUE, caption.loc='top',
                 colheads=NULL) {
  i <<- i + 1
  cat('\\clearpage\ni=', i, '\n\\hrule\n', sep='', file=file, append=TRUE)
  ib <- it <- NULL
  g <- function(x) {
    if(! length(x)) return(NULL)
    if(is.character(x)) paste(substitute(x), '=', x, ', ', sep='')
    else if(x) paste(substitute(x), '=T, ', sep='')
    else NULL
  }
  colh <- colheads
  if(insert) {
    z <- paste(g(caption), g(center), g(table.env), g(size), g(booktabs),
               g(landscape), g(ctable), g(longtable), g(hyperref),
               if(caption.loc != 'top') g(caption.loc), sep='')
    if(length(colheads)) {
      colheads <- paste(colheads, collapse=',')
      z <- paste(z, g(colheads), sep='')
    }
    it <- paste('Top: i=', i, ':', z, sep='')
    ib <- 'Text for bottom'
  }
  w <- latex(x, file=file, append=TRUE,
             caption=caption, center=center, table.env=table.env,
             size=size, booktabs=booktabs, landscape=landscape,
             ctable=ctable, longtable=longtable, hyperref=hyperref,
             insert.top=it, insert.bottom=ib, caption.loc=caption.loc,
             colheads=colh)
  invisible()
}

i <- 0
test()
test(hyperref='rrrrr')
test(caption='This caption')
test(caption='This caption, supposed to be at bottom', caption.loc='bottom')
for(cen in c('center', 'centering', 'centerline')) test(center=cen)
test(table.env=FALSE)
test(size='scriptsize')
test(table.env=FALSE)
test(booktabs=TRUE, landscape=TRUE)
test(ctable=TRUE, landscape=TRUE)
test(longtable=TRUE)
test(table.env=FALSE, colheads=FALSE)

cat('\\end{document}\n', file=file, append=TRUE)
# Run pdflatex /tmp/z
