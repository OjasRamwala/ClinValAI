library(magrittr);
library(tidyverse);

is_data_nested = function(data) any(names(data) %in% c( ".nested_data" ) )

unnest_data = function(data) data %>% unnest(.nested_data)

confirm_data_unnested = function(data) {
  if ( data %>% is_data_nested() ) {
    data = data %>% unnest_data();
  }
  return( data );
}

get_rset_meat = function(x) {
  if ( x %>% inherits("rset" ) %>% not() ) {
    rlang::abort( glue::glue( "x must be an rset but is class {class(x)}." ) );
  }
  
  if ( nrow(x) == 0 ) {
    rlang::abort( "x must have at least one row." );
  }
  
  meat = x$splits[[1]]$data;
  return( meat );
}

get_rset_skeleton = function(x) {
  if ( x %>% inherits("rset" ) %>% not() ) {
    rlang::abort( glue::glue( "x must be an rset but is class {class(x)}." ) );
  }
  
  if ( nrow(x) == 0 ) {
    rlang::abort( "x must have at least one row." );
  }
  
  data0 = x$splits[[1]]$data %>% filter(F); # zero rows but keep spec
  #data0 = NA;
  x$splits = x$splits %>%
    map(
      function(x) {
        x$data = data0;
        return( x );
      }
    )
  
  return( x );
}

put_rset_meat_on_skeleton = function(s, m) {
  if ( s %>% inherits("rset" ) %>% not() ) {
    rlang::abort( glue::glue( "s must be an rset but is class {class(x)}." ) );
  }
  
  if ( nrow(s) == 0 ) {
    rlang::abort( "s must have at least one row." );
  }
  
  s$splits = s$splits %>%
    map(
      function(x) {
        x$data = m;
        return( x );
      }
    )
  
  return( s );
}

put_rset_meat_on_rib = function(r, m) {
  if ( r %>% inherits("rsplit" ) %>% not() ) {
    rlang::abort( glue::glue( "r must be an rsplit but is class {class(x)}." ) );
  }
  
  r$data = m;
  return( r );
}

is_rset_meat_stripped = function(x) {
  if ( x %>% inherits( c( "rset", "rsplit" ) ) %>% not() ) {
    rlang::abort( glue::glue( "r must be an rset or rsplit but is class {class(x)}." ) );
  }
  
  if ( x %>% inherits( "rset" ) ) {
    s = x$splits[[1]] %>% is_rset_meat_stripped();
  } else {
    s = x$data %>% nrow() %>% equals(0);
  }
  
  return( s );
}

confirm_rset_meat_on_rib = function(r, m) {
  if ( r %>% is_rset_meat_stripped() ) {
    r = r %>% put_rset_meat_on_rib(m);
  }
  return( r );
}


get_diff_null_values = function(x) {
  if ( is.data.frame(x) ) {
    if ( any( names(x) %in% ".boot_diff_dist" ) ) {
      y = x$.boot_diff_dist %>% map_dfr( ~ .x %>% select(.metric) %>% distinct() ) %>% pull(.metric) %>% unique();
    } else if ( any( names(x) %in% ".metric" ) ) {
      y = x$.metric %>% unique()
    } else {
      rlang::abort( "x is a data.frame but does not have a .boot_diff_dist or .metric field." );
    }
  } else if ( is.character(x) ) {
    y = unique(x);
  } else {
    rlang::abort( glue::glue( "x is a {class(x)[1]} but needs to be either a data.frame or a character vector." ) );
  }
  
  z = rep( 0, length(y) ) %>% set_names(y)
  
  return( z );
}


# null_value is a named vector mapping metric names to null hypothesis values, e.g., c( "surv_cindex"=0.5, "surv_ipa"=0 )
# ... are variables to further group by, e.g., .t1 and .time
bootstrap_est = function(bd, ..., alpha = 0.05, null_value=c( ".non-metric"=0 ), na_rm=F) {
  q = qnorm( 1 - alpha/2, lower.tail=T );
  
  nv = null_value %>% enframe(".metric", "null_value" );
  if ( typeof(nv$.metric) != "character" ) {
    rlang::abort( glue::glue( "null_value must be a named vector or list."))
  }
  mt = nv$.metric %>% table()
  if ( any( mt > 1 ) ) {
    rlang::abort( glue::glue( "Multiple null values provided for some metrics."))
  }
  
  bootstrap_perc_p = function(x, null_value) {
    p1 = 2*mean( x <= null_value, na.rm=na_rm );
    p2 = 2*mean( x >= null_value, na.rm=na_rm );
    p = pmin( p1, p2, 1 );
    return( p );
  }
  
  bootstrap_norm_p = function(estimate, se, null_value) {
    p = 2*pnorm( abs( estimate - null_value ) / se, lower.tail=F );
    return( p );
  }
  
  calc_estimate = function(.estimate, id) {
    ind = id == "Apparent";
    if (any(ind)) {
      x = .estimate[ind];
      stopifnot(length(x) == 1);
    } else {
      x =  mean(.estimate, na.rm = na_rm);
    }
    return(x);
  }
  
  r = bd %>%
    left_join( nv, by=".metric" ) %>%
    group_by(.metric, ...) %>%
    #group_by(.metric, .predictor, .param, .weighted) %>%
    summarize(
      n_bootstraps = n(),
      null_value = unique( null_value ),
      #estimate = mean(.estimate, na.rm=na_rm),
      estimate = calc_estimate(.estimate, id),
      se = sd(.estimate, na.rm=na_rm),
      lower_perc = quantile( .estimate, alpha/2, na.rm=na_rm ),
      upper_perc = quantile( .estimate, 1-alpha/2, na.rm=na_rm ),
      lower_norm = estimate - q*se,
      upper_norm = estimate + q*se,
      p_perc = bootstrap_perc_p( .estimate, null_value ),
      p_norm = bootstrap_norm_p( estimate, se, null_value ),
      .groups = "drop"
    ) %>%
    pivot_longer( matches("^(upper|lower|p)_"), names_to=c( "bound", "ci_type"), names_pattern="(.+)_(.+)", values_to="ci" ) %>%
    pivot_wider( names_from="bound", values_from="ci" ) %>%
    mutate(
      ci_type = ci_type %>% factor(levels=c( "perc", "norm" ) ) %>% fct_recode( "Percentile"="perc", "Normal"="norm" )
    )
  
  return( r );
}

bootstrap_pred_est = function(bd, alpha = 0.05, null_value = c( ".non-metric"=0 ), na_rm = F) {
  bd %>% bootstrap_est(.predictor, .param, .weighted, .stratified, .subset, level, alpha = alpha, na_rm = na_rm, null_value = null_value);
}

bootstrap_group_pred_est = function(bd, alpha = 0.05, null_value = c( ".non-metric"=0 ), na_rm = F) {
  bd %>% bootstrap_est(.predictor, .param, .weighted, .stratified, .subset, level, .group_variable, .group, .group_value, alpha = alpha, na_rm = na_rm, null_value = null_value);
}






get_pred_comp = function(.x, .ref = NULL) {
  pred_comp = .x %>%
    pull(.predictor) %>%
    unique() %>%
    expand.grid(.predictor_1 = ., .predictor_2 = ., stringsAsFactors = T) %>%
    as_tibble();
  if ( is.null(.ref) ) {
    pred_comp %<>% filter(unclass(.predictor_1) > unclass(.predictor_2))
  } else {
    pred_comp %<>% filter(.predictor_2 %in% .ref, !.predictor_1 %in% .ref)
  }
  pred_comp %<>%
    mutate(
      across(everything(), as.character)
    );
  
  return( pred_comp );
}

# like get_pred_comp but with predictor replaced with group
get_group_comp = function(.x, .ref = NULL) {
  group_comp = .x %>%
    pull(.group) %>%
    unique() %>%
    expand.grid(.group_1 = ., .group_2 = ., stringsAsFactors = T) %>%
    as_tibble();
  if ( is.null(.ref) ) {
    group_comp %<>% filter(unclass(.group_1) > unclass(.group_2))
  } else {
    group_comp %<>% filter(.group_2 %in% .ref, !.group_1 %in% .ref)
  }
  group_comp %<>%
    mutate(
      across(everything(), as.character)
    );
  
  return( group_comp );
}

# pred_comp is a tibble with two character vectors: .predictor_1 and .predictor_2
# for each comparison, .predictor_1 minus .predictor_2 is calculated
# the corresponding bootstrap distributions are saved to pred_comp (.boot_dist) as well as each difference (.boot_diff_dist)
bootstrap_pred_diff_dist = function(pred_comp, bd, gv = c()) {
  pred_comp = pred_comp %>%
    mutate(
      .boot_dist = map2(
        .predictor_1,
        .predictor_2,
        ~ bd %>% filter( .predictor %in% c( .x, .y ) ) %>%
          mutate(
            .predictor = .predictor %>% factor( levels = c( .x, .y ) )
          )
      )
    );
  gv = c("id", ".metric", ".param", ".weighted", gv);
  pred_comp = pred_comp %>%
    mutate(
      .boot_diff_dist = .boot_dist %>%
        map(
          ~ .x %>%
            group_by(!!!syms(gv)) %>%
            arrange(.predictor) %>%
            summarize(
              n_pred = n(),
              splits = splits[1],
              .n = .n %>% unique() %>% paste(collapse = ";"),
              .predictor = .predictor %>% paste(collapse = " - "),
              .estimate = .estimate[1] - .estimate[2],
              .param_value = .param_value %>% paste(collapse = ";" ),
              .groups = "drop"
            ) %>%
            filter(n_pred == 2) %>%
            select(-n_pred) %>%
            mutate(
              .metric = paste( "diff", .metric, sep="_" ),
              .predictor = .predictor %>% as.character()
            )
        )
    )
  # pred_comp = pred_comp %>%
  #   mutate(
  #     .boot_dist_combined = map2(
  #       .boot_dist,
  #       .boot_diff_dist,
  #       ~ .x %>%
  #         mutate(
  #           .n = paste(.n),
  #           .param_value = .param_value %>%
  #             map_chr(
  #               ~ .x %>% list() %>% paste(collapse = ";")
  #             )
  #           ) %>%
  #         bind_rows(.y)
  #     )
  #   )
  
  return( pred_comp )
}

grouped_bootstrap_pred_diff_dist = function(pred_comp, bd) {
  pred_comp %>% bootstrap_pred_diff_dist(bd = bd, gv = c(".group_variable", ".group", ".group_value"))
}

# analogous to bootstrap_pred_diff_dist
bootstrap_group_diff_dist = function(group_comp, bd, gv = c()) {
  group_comp = group_comp %>%
    mutate(
      .boot_dist = map2(
        .group_1,
        .group_2,
        ~ bd %>% filter( .group %in% c( .x, .y ) ) %>%
          mutate(
            .group = .group %>% factor( levels = c( .x, .y ) )
          )
      )
    );
  gv = c("id", ".predictor", ".metric", ".param", ".weighted", ".group_variable", gv);
  group_comp = group_comp %>%
    mutate(
      .boot_diff_dist = .boot_dist %>%
        map(
          ~ .x %>%
            #group_by(id, .predictor, .metric, .param, .weighted, .group_variable) %>%
            group_by(!!!syms(gv)) %>%
            arrange(.predictor) %>%
            summarize(
              n_group = n(),
              splits = splits[1],
              .n = .n %>% paste(collapse = ";"),
              .group = .group %>% paste(collapse = " - "),
              .group_value = .group_value %>% paste(collapse = " - "),
              .estimate = .estimate[1] - .estimate[2],
              .param_value = .param_value %>% paste(collapse = ";" ),
              .groups = "drop"
            ) %>%
            filter(n_group == 2) %>%
            select(-n_group) %>%
            mutate(
              .group = .group %>% as.character()
            )
        )
    )
  
  return( group_comp );
}



