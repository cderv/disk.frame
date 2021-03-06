#' Add a chunk to the disk.frame
#' @param df the disk.frame to add a chunk to
#' @param chunk a data.frame to be added as a chunk
#' @param chunk_id a numeric number indicating the id of the chunk. If NULL it will be set to the largest chunk_id + 1
#' @export
add_chunk <- function(df, chunk, chunk_id = NULL) {
  #browser()
  stopifnot("disk.frame" %in% class(df))
  if(!is_disk.frame(df)) {
    stop("can not add_chunk as this is not a disk.frame")
  }
    # get the metadata for all chunks
  files <- fs::dir_ls(attr(df,"path"), type="file")
  path = attr(df,"path")
  
  if(is.null(chunk_id)) {
    chunk_id = 1 + max(purrr::map_int(files, ~{
      s = stringr::str_extract(.x,"[:digit:]+\\.fst")
      as.integer(substr(s, 1, nchar(s) - 4))
    }), nchunks(df))
  }
  
  if(length(files) > 0) {
    filename = ""
    
    if(is.numeric(chunk_id)) {
      filename = file.path(path,glue::glue("{as.integer(chunk_id)}.fst"))
    } else {
      if (full.names) {
        filename = chunk_id
      } else {
        filename = file.path(path, chunk_id)
      }
    }
    
    if(fs::file_exists(filename)) {
      stop(glue::glue("failed to add_chunk as chunk_id = {chunk_id} already exist"))
    }
    
    metas = purrr::map(files, fst::metadata_fst)
    
    types <- c("unknown", "character", "factor", "ordered factor", 
               "integer", "POSIXct", "difftime", "IDate", "ITime", "double", 
               "Date", "POSIXct", "difftime", "ITime", "logical", "integer64", 
               "nanotime", "raw")
    
    # need to ensure that all column names and types match
    metas_df = purrr::imap_dfr(metas, 
                              ~data.table(
                                colnames = .x$columnNames, 
                                coltypes = types[.x$columnTypes],
                              chunk_id = .y))
    
    metas_df_summ = metas_df[,.N,.(colnames, coltypes)][order(N)]
    metas_df_summ[,existing_df := T]
    
    new_chunk_meta = data.table(colnames = names(chunk), coltypes = purrr::map(chunk, typeof) %>% unlist, new_chunk = TRUE)
    
    merged_meta = full_join(new_chunk_meta, metas_df_summ, by=c("colnames"))
    
    # find out which vars are matched
    check_vars = full_join(new_chunk_meta[,.(colnames, new_chunk)], metas_df[,.(colnames=unique(colnames), existing_df = TRUE)], by = "colnames")
    if(nrow(check_vars[is.na(new_chunk)]) > 0) {
      warning(
        glue::glue(
          "these variables are in the disk.frame but not in the new chunk {paste0(check_vars[is.na(new_chunk), colnames], collapse=', ')}"))
    }
    if(nrow(check_vars[is.na(existing_df)]) > 0){
      warning(glue::glue("these variables are in the new chunk but not in the existing disk.frame: {paste0(check_vars[is.na(existing_df), colnames], collapse=', ')}"))
    }
    
    # find out which vars are matched but the types don't match
    metas_df_summ1 = merged_meta[existing_df == T & new_chunk == T & coltypes.x != coltypes.y]
    # find incompatible types
    metas_df_summ1[, incompatible_types := {
      coltypes.x %in% c("integer", "double", "Date") & coltypes.y == "character" |
      coltypes.x == "character" & coltypes.y %in% c("integer", "double", "Date") |
      coltypes.x %in% c("integer", "double") & coltypes.y == "Date" | 
      coltypes.x == "Date" & coltypes.y %in% c("integer", "double")
    }]
    
    metas_df_summ2 = metas_df_summ1[incompatible_types == T,]
    
    if(nrow(metas_df_summ2)) {
      print("the belows types are incompatible between the new chunk and the disk.frame; this chunk can not be added")
      print(metas_df_summ2)
      stop("")
    }
  }
  write_fst(chunk, file.path(attr(df,"path"),paste0(chunk_id,".fst")))
}