#' dplyr version implemented for disk.frame
#' @export
#' @import dplyr
#' 
#' @rdname dplyr_verbs
select_.disk.frame <- function(.data, ..., .dots){
  .dots <- lazyeval::all_dots(.dots, ...)
  cmd <- lazyeval::lazy(select_(.data, .dots=.dots))
  record(.data, cmd)
}


#' @export
#' @rdname dplyr_verbs
rename_.disk.frame <- function(.data, ..., .dots){
  .dots <- lazyeval::all_dots(.dots, ...)
  cmd <- lazyeval::lazy(rename_(.data, .dots=.dots))
  record(.data, cmd)
  #stop("not implemented rename!")
}

#' @export
#' @rdname dplyr_verbs
filter_.disk.frame <- function(.data, ..., .dots){
  .dots <- lazyeval::all_dots(.dots, ...)
  cmd <- lazyeval::lazy(filter_(.data, .dots=.dots))
  record(.data, cmd)
}

#' mutate
#' @export
#' @rdname dplyr_verbs
mutate_.disk.frame <- function(.data, ..., .dots){
  .dots <- lazyeval::all_dots(.dots, ...)
  cmd <- lazyeval::lazy(mutate_(.data, .dots=.dots))
  record(.data, cmd)
}

#' transmuate
#' @export
#' @rdname dplyr_verbs
transmute_.disk.frame <- function(.data, ..., .dots){
  .dots <- lazyeval::all_dots(.dots, ...)
  cmd <- lazyeval::lazy(transmute_(.data, .dots=.dots))
  record(.data, cmd)
}

#' @export
#' @rdname dplyr_verbs
arrange_.disk.frame <- function(.data, ..., .dots){
  warning("disk.frame only sorts (arange) WITHIN each chunk")
  .dots <- lazyeval::all_dots(.dots, ...)
  cmd <- lazyeval::lazy(arrange_(.data, .dots=.dots))
  record(.data, cmd)
}

#' @export
#' @rdname dplyr_verbs
summarise_.disk.frame <- function(.data, ..., .dots){
  .data$.warn <- TRUE
  .dots <- lazyeval::all_dots(.dots, ...)
  cmd <- lazyeval::lazy(summarise_(.data, .dots=.dots))
  record(.data, cmd)
}

#' @export
#' @rdname dplyr_verbs
do_.disk.frame <- function(.data, ..., .dots){
  warning("applying `do` to each chunk of disk.frame; this may not work as expected")
  .dots <- lazyeval::all_dots(.dots, ...)
  cmd <- lazyeval::lazy(do_(.data, .dots=.dots))
  record(.data, cmd)
}

#' Group
#' @export
#' @rdname group_by
groups.disk.frame <- function(x){
  shardkey(x)
}

#' Group by designed for disk.frames
#' @import dplyr purrr
#' @export
#' @rdname group_by
group_by.disk.frame <- function(.data, ..., add = FALSE, hard = NULL, outdir = NULL) {
  #browser()
  dots <- dplyr:::compat_as_lazy_dots(...)
  shardby = purrr::map_chr(dots, ~deparse(.x$expr))
  
  if (hard == TRUE) {
    if(is.null(outdir)) {
      outdir = tempfile("tmp_disk_frame")
    }
    
    .data = hard_group_by(.data, by = shardby, outdir = outdir)
    #list.files(
    .data = dplyr::group_by_(.data, .dots = dplyr:::compat_as_lazy_dots(...), add = add)
    return(.data)
  } else if (hard == FALSE) {
    shardinfo = shardkey(.data)
    if(!identical(shardinfo[[1]], shardby)) {
      warning(glue::glue(
        "hard is set to FALSE but the shardkeys '{shardinfo[[1]]}' are NOT identical to shardby = '{shardby}'. The group_by operation is applied WITHIN each chunk, hence the results may not be as expected. To address this issue, you can group_by(..., hard = TRUE) which can be computationally expensive. Otherwise, you may use a second stage summary to obtain the desired result."))
    }
    return(dplyr::group_by_(.data, .dots = dplyr:::compat_as_lazy_dots(...), add = add))
  } else {
    stop("group_by operations for disk.frames must be set hard to TRUE or FALSE")
  }
}

#' @export
#' @rdname group_by
group_by_.disk.frame <- function(.data, ..., .dots, add=FALSE){
  .dots <- lazyeval::all_dots(.dots, ...)
  cmd <- lazyeval::lazy(group_by_(.data, .dots=.dots, add=add))
  record(.data, cmd)
}

#' Take a glimpse
#' @export
#' @rdname dplyr_verbs
glimpse.disk.frame <- function(df, ...) {
  glimpse(head(df, ...), ...)
}

#' Internal methods
record <- function(.data, cmd){
  attr(.data,"lazyfn") <- c(attr(.data,"lazyfn"), list(cmd))
  .data
}

#' Internal methods
play <- function(.data, cmds=NULL){
  #list.files(
  for (cmd in cmds){
    if (typeof(cmd) == "closure") {
      .data <- cmd(.data)
      #print(.data)
    } else {
      .data <- lazyeval::lazy_eval(cmd, list(.data=.data)) 
    }
  }
  .data
}