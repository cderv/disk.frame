#' Obtain one chunk by chunk id
#' @param df a disk.frame
#' @param n the chunk id. If numeric then matches by number, if character then returns the chunk with the same name as n
#' @param keep the columns to keep
#' @param full.name whether n is the full path to the chunks or just a relative path file name. Ignored if n is numeric
#' @param ... passed to fst::read_fst or whichever read function is used in the backend
#' @export
get_chunk <- function(...) {
  UseMethod("get_chunk")
}


#' @rdname get_chunk
#' @import fst
#' @export
get_chunk.disk.frame <- function(df, n, keep = NULL, full.names = F, ...) {
  #browser()
  stopifnot("disk.frame" %in% class(df))
  
  path = attr(df,"path")
  keep1 = attr(df,"keep")
  
  cmds = attr(df,"lazyfn")
  filename = ""
  
  if (typeof(keep) == "closure") {
    keep = keep1
  } else if(!is.null(keep1) & !is.null(keep)) {
    keep = intersect(keep1, keep)
    if (!all(keep %in% keep1)) {
      warning("some of the variables specified in keep = {keep} is not available")
    }
  } else if(is.null(keep)) {
    keep = keep1
  }
  
  if(is.numeric(n)) {
    #filename = list.files(path, full.names = T)[n]
    filename = file.path(path, paste0(n,".fst"))
  } else {
    if (full.names) {
      filename = n
    } else {
      filename = file.path(path, n)
    }
  }
  
  # if the file you are looking for don't exist
  if (!fs::file_exists(filename)) {
    warning(glue("The chunk {filename} does not exist; returning an empty data.table"))
    notbl <- data.table()
    attr(notbl, "does not exist") <- T
    return(notbl)
  }

  if (is.null(cmds)) {
    if(typeof(keep)!="closure") {
      read_fst(filename, columns = keep, as.data.table = T,...)
    } else {
      read_fst(filename, as.data.table = T,...)
    }
  } else {
    if(typeof(keep)!="closure") {
      disk.frame:::play(read_fst(filename, columns = keep, as.data.table = T,...), cmds)
    } else {
      disk.frame:::play(read_fst(filename, as.data.table = T,...), cmds)
    }
  }
}
