#!/usr/bin/Rscript

# ---- inferentials ----

options(error=traceback)
              # Single Case
library(SCRT) # Randomisation Tests
#library(SCVA) # Visual Analysis
library(SCMA) # Meta Analysis
library(plyr)
library(xtable)
library(stringr)
library(psy)
library(devtools)
load_all('/home/paul/src/R/SCVA',quiet=TRUE) # customised SCVA package

root      <- '/home/paul/Documents/psychology/msc/M210/apprenticeship'
results_d <- paste(root,'/dissertation/results',sep="")
source(paste(root,'/opensesame/dotprobe/constants.r',sep=""))

setwd(datadir)

# design properties
design <- 'AB'
mt     <- 35 # FIXME: varies per P
limit  <- 8

## functions

do_cronbach <- function(s,data) {
  session <- data[data$session == s,]
  session <- subset(session, select=-c(participant,session))
  c <- cronbach(session)
  c$alpha
}

printf <- function(...) cat(sprintf(...))

pvalue <- function(p) {
  p <- as.numeric(p)
  if (round(p, digits=2) < 0.001) {
    p <- '< .001'
  } else {
    p <- sprintf("%0.3f",p)
    p <- str_replace(as.character(p), "^0\\.", ".")
  }
  p
}

ylab <- list(i="I-Word Attentional Bias Score (ms)",n="N-Word Attentional Bias Score (ms)",grs="GRS Score",pa="PA Score",na="NA Score",d="Depression ('sad'+'depressed') Score")
X11(type="cairo")

## analyse daily outcomes for each participant
p <- participants
rt <- data.frame(participant=p,i_mean_a=p,i_sd_a=p,i_mean_b=p,i_sd_b=p,i_p=p,i_pnd=p,n_mean_a=p,n_sd_a=p,n_mean_b=p,n_sd_b=p,n_p=p,n_pnd=p)
panas <- data.frame(participant=p,pa_mean_a=p,pa_sd_a=p,pa_mean_b=p,pa_sd_b=p,pa_p=p,pa_pnd=p,na_mean_a=p,na_sd_a=p,na_mean_b=p,na_sd_b=p,na_p=p,na_pnd=p,d_mean_a=p,d_sd_a=p,d_mean_b=p,d_sd_b=p,d_p=p,d_pnd=p)
grs <- data.frame(participant=p,mean_a=p,sd_a=p,mean_b=p,sd_b=p,p=p,pnd=p)

## Cronbach's alpha

no_zero <- function(x) {
  if (as.double(x) == 0) {
    x
  } else {
    str_replace(x, "^0\\.", ".")
  }
}

set_alpha <- function(outcome,a) {
  x <- sprintf("%0.2f",c(median(c),range(c)))
  dim(x) <- 3
  x <- apply(x,1,no_zero)
  alpha[outcome,c('median','range1','range2')] <<- x
}

# all daily measures
measures_f    <- paste(datadir,'measures.csv',sep='')
daily         <- read.csv(measures_f,header=TRUE)
daily         <- daily[daily$lastpage == 3,] # only completed surveys
# FIXME: remove bad sessions
# http://stackoverflow.com/questions/6601658/deleting-specific-rows-from-a-data-frame
# HACK: should read 'bad' sessions rather than hard-code them
daily         <- daily[! (grepl('7',daily$participant) & grepl('32',daily$session)), ]
#daily[daily$participant == 7,c('participant','session')]
max_sessions      <- 1:35
dim(max_sessions) <- c(35,1)

schedules_f <- paste(datadir,'rumination study - schedules.csv',sep='')
schedules   <- read.csv(schedules_f,as.is=TRUE) # ignore non-numerics in Participants column
sessions    <- schedules[schedules$'Participant' %in% participants,c('Participant','Complete')]
sessions    <- rename(sessions,c('Participant'='participant','Complete'='sessions'))
sessions[,'participant'] <- sapply(sessions[,'participant'], as.numeric)

# HACK: reduce sessions by number of 'bad' sessions
sessions[sessions$participant == 7,'sessions'] <- sessions[sessions$participant == 7,'sessions'] - 1
alpha <- data.frame(median=1:4,range1=1:4,range2=1:4,row.names=c('PA','NA','d','GRS'))

## GRS
grs_f <- sprintf('grs.SQ%03d',1:4)
grs_r <- sprintf('grs.SQ%03d',5:7)
data  <- daily[daily$'participant' %in% participants,c('participant','session',grs_f,grs_r)]
reverse_grs <- function(x) { 7 - x + 1} # reverse item (7 point scale)
data  <- cbind(data[,c('participant','session',grs_f)],apply(data[grs_r],2,reverse_grs))
c     <- sapply(max_sessions,do_cronbach,data=data)
set_alpha('GRS',c)

## PANAS

# d
d_items <- sprintf('panas.SQ%03d',c(11,13))
data    <- daily[daily$'participant' %in% participants,c('participant','session',d_items)]
c       <- sapply(max_sessions,do_cronbach,data=data)
set_alpha('d',c)

# PA
pa_items <- sprintf('panas.SQ%03d',c(2,5,6,7,9))
data     <- daily[daily$'participant' %in% participants,c('participant','session',pa_items)]
c        <- sapply(max_sessions,do_cronbach,data=data)
set_alpha('PA',c)

# NA
na_items <- sprintf('panas.SQ%03d',c(1,3,4,8,10))
data     <- daily[daily$'participant' %in% participants,c('participant','session',na_items)]
c        <- sapply(max_sessions,do_cronbach,data=data)
set_alpha('NA',c)

# maxima
# http://stackoverflow.com/questions/2104483/how-to-read-table-multiple-files-into-a-single-table-in-r
read.tables <- function(file.names, ...) {
  ldply(file.names, function(fn) data.frame(Filename=fn, read.table(fn, ...)))
}

dv<-c('i','n','grs','pa','na','d')
minmax <- mapply(function(dv) {
  files <- mapply(function(p,dv) { sprintf("%s%s/p%d_%s_scores",datadir,p,p,dv) },participants,dv=dv)
  data  <- read.tables(files)
  list(min(data$V2),max(data$V2))
},dv)
rownames(minmax)<-c('min','max')

for (participant in participants) {
  p_dir <- paste(datadir,participant,'/',sep='')
  for (dv in c('i','n','grs','pa','na','d')) {
    #printf("DV: %s\n",dv);
    dv_f <- paste(p_dir,'p',participant,'_',dv,'_scores',sep='')
    # generate plot for visual analysis
    data <- read.table(dv_f)
    completed <- sessions[sessions$'participant' == participant,'sessions']
    xlab = paste('Session (Participant ',participant,'; ',completed,' sessions)',sep='')
    #graph.CL(design,'bmed',data=data,xlab=xlab,ylab=ylab[[dv]],a_legend='A (baseline)',b_legend='B (ABM training)',minmax=minmax[,dv])
    #savePlot(filename=paste(p_dir,'p',participant,'_',dv,'.jpg',sep=''), type='jpeg')
    if (dv == 'n') {             ## bias score
      # FIXME: is A-B or B-A the correct test statistic for bias scores?!!
      #statistic <- 'A-B'        # 1-tailed: expect B to be more negative than A i.e. increased avoidance of N/I words
      statistic <- '|A-B|'       # Agreed with Nick to do them all 2-tailed
      ES <- 'PND-'               # expect negative bias score i.e. increased avoidance of N/I words
    } else {                     ## GRS, PANAS
      statistic <- '|A-B|'       # FIXME: 2-tailed? is probably correct
      if (dv == 'pa') { 
	ES <- 'PND+'             # expect increased PA
      } else {
	ES <- 'PND-'             # expect decreased GRS, NA and depression
      }
    }
    p   <- pvalue.systematic(design,statistic,save = "no",limit = limit, data = data)
    pnd <- ES(design,ES,data = data)
    # caclulate mean and sd for phases A and B
    a      <- data[data$V1 == 'A','V2']
    mean_a <- mean(a)
    sd_a   <- sd(a)
    b      <- data[data$V1 == 'B','V2']
    mean_b <- mean(b)
    sd_b   <- sd(b)
    if (dv == 'i' | dv == 'n') {                       # RTs table
      rt[rt$participant == participant,paste(dv,'_','mean_a',sep='')] <- mean_a
      rt[rt$participant == participant,paste(dv,'_','sd_a',sep='')]   <- sd_a
      rt[rt$participant == participant,paste(dv,'_','mean_b',sep='')] <- mean_b
      rt[rt$participant == participant,paste(dv,'_','sd_b',sep='')]   <- sd_b
      rt[rt$participant == participant,paste(dv,'_','p',sep='')]      <- p
      rt[rt$participant == participant,paste(dv,'_','pnd',sep='')]    <- pnd
    } else if (dv == 'pa' | dv == 'na' | dv == 'd') {  # PANAS table
      panas[panas$participant == participant,paste(dv,'_','mean_a',sep='')] <- mean_a
      panas[panas$participant == participant,paste(dv,'_','sd_a',sep='')]   <- sd_a
      panas[panas$participant == participant,paste(dv,'_','mean_b',sep='')] <- mean_b
      panas[panas$participant == participant,paste(dv,'_','sd_b',sep='')]   <- sd_b
      panas[panas$participant == participant,paste(dv,'_','p',sep='')]      <- p
      panas[panas$participant == participant,paste(dv,'_','pnd',sep='')]    <- pnd
    } else {                                           # GRS table
      grs[grs$participant == participant,'p']      <- p
      grs[grs$participant == participant,'pnd']    <- pnd
      grs[grs$participant == participant,'mean_a'] <- mean_a
      grs[grs$participant == participant,'sd_a']   <- sd_a
      grs[grs$participant == participant,'mean_b'] <- mean_b
      grs[grs$participant == participant,'sd_b']   <- sd_b
    }
  }
}

# ha ha ha! stack overflow et al. are use cases/patterns!!
# http://stackoverflow.com/questions/9950144/access-lapply-index-names-inside-fun
ma <- c('i'=0,'n'=0,'pa'=0,'na'=0,'d'=0,'grs'=0)
ma <- sapply(seq_along(ma), function(p,outcome,i) {
  o <- outcome[[i]]
  if (o == 'i') {
    ps <- rt$i_p
  } else if (o == 'n') {
    ps <- rt$n_p
  } else if (o == 'pa') {
    ps <- panas$pa_p
  } else if (o == 'na') {
    ps <- panas$na_p
  } else if (o == 'd') {
    ps <- panas$d_p
  } else {
    ps <- grs$p
  }
  f <- '/tmp/p.tsv'
  write.table(ps, file=f, quote=FALSE, sep='\t', row.name=FALSE, col.names=FALSE)
  c(o,combine('+',pvalues = read.table(f))) # additive method (Edgington, 1972)
}, p=ma,outcome=names(ma))
meta_p <- ma[2,]
meta_p <- as.numeric(meta_p)
meta_p <- sapply(meta_p, pvalue)
names(meta_p) <- ma[1,]

# merge sessions completed into tables
rt    <- merge(sessions,rt,by='participant')
rt    <- rt[with(rt, order(participant)), ]
grs   <- merge(sessions,grs,by='participant')
grs   <- grs[with(grs, order(participant)), ]
panas <- merge(sessions,panas,by='participant')
panas <- panas[with(panas, order(participant)), ]

format_direction <- function(a,b,sd,diff='<') {
  v <- b
  sd <- as.numeric(sd)
  if ( diff == '>' ) { # test for b > a
    c <- a
    a <- b
    b <- c
  }
  if (b < a) {
    sprintf("\\textbf{%0.2f(%0.2f)}",v,sd)
  } else {
    sprintf("%0.2f(%0.2f)",v,sd)
  }
}

format_grs <- function(x) {
  x['p']   <- pvalue(x['p'])
  x['pnd'] <- sprintf("%0.2f",as.numeric(x['pnd']))
  a <- as.numeric(x['mean_a'])
  b <- as.numeric(x['mean_b'])
  x['a'] <- sprintf("%0.2f(%0.2f)",a,as.numeric(x['sd_a']))
  x['b'] <- format_direction(a,b,x['sd_b'])
  x
}

format_rt <- function(x) {
  x['i_p']   <- pvalue(x['i_p'])
  x['i_pnd'] <- sprintf("%0.2f",as.numeric(x['i_pnd']))
  a          <- as.numeric(x['i_mean_a'])
  b          <- as.numeric(x['i_mean_b'])
  x['i_a']   <- sprintf("%0.2f(%0.2f)",a,as.numeric(x['i_sd_a']))
  x['i_b']   <- format_direction(a,b,x['i_sd_b'])
  x['n_p']   <- pvalue(x['n_p'])
  x['n_pnd'] <- sprintf("%0.2f",as.numeric(x['n_pnd']))
  a          <- as.numeric(x['n_mean_a'])
  b          <- as.numeric(x['n_mean_b'])
  x['n_a']   <- sprintf("%0.2f(%0.2f)",a,as.numeric(x['n_sd_a']))
  x['n_b']   <- format_direction(a,b,x['n_sd_b'])
  x
}

format_panas <- function(x) {
  x['pa_p']   <- pvalue(x['pa_p'])
  x['pa_pnd'] <- sprintf("%0.2f",as.numeric(x['pa_pnd']))
  a <- as.numeric(x['pa_mean_a'])
  b <- as.numeric(x['pa_mean_b'])
  x['pa_a'] <- sprintf("%0.2f(%0.2f)",a,as.numeric(x['pa_sd_a']))
  x['pa_b'] <- format_direction(a,b,x['pa_sd_b'],diff='>')

  x['na_p']   <- pvalue(x['na_p'])
  x['na_pnd'] <- sprintf("%0.2f",as.numeric(x['na_pnd']))
  a <- as.numeric(x['na_mean_a'])
  b <- as.numeric(x['na_mean_b'])
  x['na_a']  <- sprintf("%0.2f(%0.2f)",a,as.numeric(x['na_sd_a']))
  x['na_b']  <- format_direction(a,b,x['na_sd_b'])

  x['d_p']   <- pvalue(x['d_p'])
  x['d_pnd'] <- sprintf("%0.2f",as.numeric(x['d_pnd']))
  a <- as.numeric(x['d_mean_a'])
  b <- as.numeric(x['d_mean_b'])
  x['d_a'] <- sprintf("%0.2f(%0.2f)",a,as.numeric(x['d_sd_a']))
  x['d_b'] <- format_direction(a,b,x['d_sd_b'])
  x
}

# LaTeX table wording
meta_label <- "${p}$$_{meta}$\\tabfnm{c}"
## PANAS table
options(xtable.sanitize.text.function=identity)
p_head     <- "${p}$\\footnote{\\label{randp1}${p}$ value from randomisation test \\parencite{bulte_r_2008}}"
p_head_ref <- "${p}$\\textsuperscript{\\ref{randp1}}"
pa_head    <- paste("\\multicolumn{4}{l}{Positive Affect (PA)\\footnote{Cronbach's $\\alpha$: median = ",alpha['PA','median'],", range = ",alpha['PA','range1'],"--",alpha['PA','range2'],"}}",sep='')
na_head    <- paste("\\multicolumn{4}{l}{Negative Affect (NA)\\footnote{Cronbach's $\\alpha$: median = ",alpha['NA','median'],", range = ",alpha['NA','range1'],"--",alpha['NA','range2'],"}}",sep='')
d_head     <- paste("\\multicolumn{4}{l}{Depression (items 'sad' and 'depressed') \\footnote{Cronbach's $\\alpha$: median = ",alpha['d','median'],", range = ",alpha['d','range1'],"--",alpha['d','range2'],"}}",sep='')
results <- apply(panas,1,format_panas)
results <- t(results)
results <- subset(results, select=c(participant,sessions,pa_a,pa_b,pa_p,pa_pnd,na_a,na_b,na_p,na_pnd,d_a,d_b,d_p,d_pnd))
strCaption <- paste0("Randomisation tests and meta-analysis for positive affect (PA), negative affect (NA) and depression. Values in \\textbf{bold} indicate changes in hypothesised direction.")
sink(paste(results_d,'/panas.tex',sep=''),append=FALSE,split=FALSE)
print(xtable(results, caption=strCaption, label="tab:panas", align=c('c','c','c','l','l','r','r@{\\hspace{2em}}','l','l','r','r@{\\hspace{2em}}','l','l','r','r')),
      size="scriptsize",
      include.rownames=FALSE,
      include.colnames=FALSE,
      floating.environment='sidewaystable',
      table.placement='!htbp',
      caption.placement="top",
      hline.after=NULL,
      add.to.row = list(pos = list(-1, nrow(results)),
                        command = c(paste("\\toprule \n",
					  "& & ",pa_head," & ",na_head," & ",d_head,"\\\\\n",
                                          "\\cline{3-14} \n",
                                          "Participant & Sessions & Phase A ${M}$(${SD}$) & Phase B ${M}$(${SD}$)
					  & ", p_head, "& ${PND}$ & Phase A ${M}$(${SD}$) & Phase B
					  ${M}$(${SD}$) & ", p_head_ref, "& ${PND}$ & Phase A ${M}$(${SD}$) &
					  Phase B ${M}$(${SD}$) & ", p_head_ref, " & ${PND}$\\\\\n",
                                          "\\midrule \n"),
				          paste("\\cline{5-5} \\cline{9-9} \\cline{13-13}\n","& & & ${p}$$_{meta}$\\footnote{Meta-analytic ${p}$ value \\parencite{onghena_customization_2005}.} & ", meta_p['pa'], "& & & & ", meta_p['na'],"& & & & ", meta_p['d'],"\\\\\n",
						  "\\bottomrule \n"))
				    )
		      )
sink()

## RT table
options(xtable.sanitize.text.function=identity)
results <- apply(rt,1,format_rt)
results <- t(results)
results <- subset(results, select=c(participant,sessions,i_a,i_b,i_p,i_pnd,n_a,n_b,n_p,n_pnd))
strCaption <- paste0("Randomisation tests and meta-analysis for I-word and N-word dot-probe scores\\tabfnm{a}. Values in \\textbf{bold} indicate reductions in attentional bias after ABM training.")
p_head     <- "${p}$\\tabfnm{b}"
{
  sink('/dev/null')
  table <- print(xtable(results, caption=strCaption, label="tab:rt", align=c('c','c','c','l','l','r','r','l','l','r','r')),
      size='footnotesize',
      include.rownames=FALSE,
      include.colnames=FALSE,
      floating.environment='sidewaystable',
      table.placement='!htbp',
      caption.placement="top",
      hline.after=NULL,
      add.to.row = list(pos = list(-1, nrow(results)),
                        command = c(paste("\\toprule \n",
					  "& & I words & & & & N words\\\\\n",
                                          "\\cline{3-8} \n",
					  "& & A & B & & & A & B\\\\\n",
                                          "\\cline{3-10} \n",
                                          "Participant & Sessions &
					  ${M}$(${SD}$) & ${M}$(${SD}$) & ",
					  p_head, " & ${PND}$ & ${M}$(${SD}$) &
					  ${M}$(${SD}$) & ~", p_head, " & ${PND}$\\\\\n",
                                          "\\midrule \n"),
				          paste("\\cline{5-5} \\cline{9-9}
						\n","& & &", meta_label, " & ",
						meta_p['i'], "& & & & ",
						meta_p['n'], "\\\\\n",
                                          "\\bottomrule \n"))
				    )
		      )
  sink()
}

# footnotes
fn <- paste("\\begin{tablenotes}[para,flushleft]\n{\\footnotesize\n\\tabfnt{a}For both I-words and N-words, more negative scores indicate avoidance, and more positive scores vigilance.\n\\tabfnt{b}${p}$ value from randomisation test \\parencite{bulte_r_2008}\n\\tabfnt{c}Meta-analytic ${p}$ value \\parencite{onghena_customization_2005}.\n}\n\\end{tablenotes}\n\\end{threeparttable}\n\\end{sidewaystable}",sep='')
table = sub("\\begin{sidewaystable}","\\begin{sidewaystable}[!htbp]\n\\begin{threeparttable}\n",table,fixed=TRUE)
table = sub("\\end{sidewaystable}",fn,table,fixed=TRUE)
sink(paste(results_d,'/rt.tex',sep=''),append=FALSE,split=FALSE)
cat(table)
sink()

## GRS table
p_head  <- "${p}$\\tabfnm{b}"
results <- apply(grs,1,format_grs)
results <- t(results)
results <- subset(results, select=c(participant,sessions,a,b,p,pnd))
meta_label <- "${p}$$_{meta}$\\tabfnm{c}"
strCaption <- paste0("Randomisation tests and meta-analysis for GRS\\tabfnm{a}. Values in \\textbf{bold} indicate changes in hypothesised direction.")
{
  sink('/dev/null')
  table <- print(xtable(results, caption=strCaption, label="tab:grs", align=c('c','c','c','l','l','r','r')),
      size="footnotesize",
      include.rownames=FALSE,
      include.colnames=FALSE,
      floating.environment='table',
      caption.placement="top",
      hline.after=NULL,
      add.to.row = list(pos = list(-1, nrow(results)),
                        command = c(paste("\\toprule \n",
					  "& & A & B \\\\\n",
                                          "\\cline{3-4} \n",
                                          "Participant & Sessions & ${M}$(${SD}$) & ${M}$(${SD}$) & ", p_head, "& ${PND}$\\\\\n",
                                          "\\midrule \n"),
				          paste("\\cline{5-5} \n","& & &", meta_label, " & ", meta_p['grs'], "\\\\\n",
                                          "\\bottomrule \n"))
				    )
		      )
  sink()
}
# footnotes
fn <- paste("\\begin{tablenotes}[para,flushleft]\n{\\footnotesize\n\\tabfnt{a}Cronbach's $\\alpha$: median = ",alpha['PA','median'],", range = ",alpha['PA','range1'],"--",alpha['PA','range2'],"\n\\tabfnt{b}${p}$ value from randomisation test \\parencite{bulte_r_2008}\n\\tabfnt{c}Meta-analytic ${p}$ value \\parencite{onghena_customization_2005}.\n}\n\\end{tablenotes}\n\\end{threeparttable}\\end{table}",sep='')
#table = sub("{table}","{threeparttable}",table,fixed=TRUE)
table = sub("\\begin{table}","\\begin{table}[!htbp] \\centering\n\\begin{threeparttable}\n",table,fixed=TRUE)
table = sub("\\end{table}",fn,table,fixed=TRUE)
sink(paste(results_d,'/grs.tex',sep=''),append=FALSE,split=FALSE)
cat(table)
sink()

# MBD
# GRS
mbd <- function() {
  #print("MBD GRS");
  # MBD randomization analysis, requires additional "possible start points" file
  #p <- pvalue.systematic('MBD',statistic,save = "no",limit = limit, data = read.table(mbd_grs), starts = starts_f)
  starts_f <- paste(datadir,'starts',sep='')
  mbd_grs <- paste(datadir,'mbd_grs_1',sep='')
  cat(mbd_grs,' ',starts_f,"\n")
  #p <- pvalue.systematic('MBD',statistic,save = "no",limit = limit, data = read.table(mbd_grs), starts = starts_f)
  p <- pvalue.random('MBD',statistic,save = "no",limit = limit, number=1000, data = read.table(mbd_grs), starts = starts_f)
  #printf("p = %0.3f\n",p)
  stop()
  # FIXME: what's the difference between pvalue.systematic(design="MBD" ...) and SCMA as they both produce 1 p value?
  for (i in 2:6) { # MBD divided into 6 blocks for testing graph output, possibly invalid approach!!!
    block <- paste('mbd_grs_',i,sep='')
    jpg <- paste(block,'.jpg',sep='')
    jpeg(jpg)
    mbd_grs <- paste(datadir,block,sep='')
    graph.CL('MBD','mean',data=read.table(mbd_grs),xlab="Measurement Times",ylab="GRS Score")
    dev.off()
  }
}

#mbd()

make_schedule <- function() {
  #quantity(design="AB",MT=15,limit=6)
  #[1] 4
  #cat("design = ",design,", mt = ",mt,", limit = ",limit,"\n", sep='')
  #cat("transitions = ",quantity(design=design,MT=mt,limit=limit),"\n", sep='')
  schedule <- selectdesign(design=design,MT=mt,limit=limit)
  cat(schedule,"\n")
}
