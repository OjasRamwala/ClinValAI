library(magrittr);
library(tidyverse);
library(survival);

calc_brier = function(data, ev, pv) {
  e = data %>% pull(ev);
  p = data %>% pull(pv);
  
  p %>% subtract(e) %>% raise_to_power(2) %>% mean()
}

calc_cindex = function(data, tv, ev, pv, time_max = NULL) {
  x = data %>% select(all_of(c(tv, ev, pv)));
  
  if (is.null(time_max)) {
    time_max  = x %>% pull(1) %>% max();
    rlang::inform(str_glue("Setting time_max to maximum value in {tv} = {time_max}"))
  }
  
  r = try(
    x %>% 
      as.matrix() %>%
      survC1::Est.Cval(
        tau = time_max, 
        nofit = T
      )
  );
  if (inherits(r, "try-error")) {
    r2 = NA_real_
  } else {
    r2 = r$Dhat
  }
  
  return(r2);
}

grouped_summary = function(data, group, fun, ..., .inc_all = F, .inc_na = T) {
  r1 = NULL;
  if ( .inc_all ) {
    r1 = data %>%
      fun(...) %>%
      mutate(
        .group_variable = "none",
        .group = "all",
        .group_value = NA,
        .before = 1
      );
  }
  
  r2 = data %>%
    group_by({{group}}) %>%
    summarize(
      #.results = list(cur_data()),
      .results = pick(everything()) %>% list(),
      .group_variable = cur_group() %>% imap(~ glue::glue("{.y}")) %>% paste(collapse = ", "),
      .group = cur_group() %>% imap(~ glue::glue("{.y} = {.x}")) %>% paste(collapse = ", "),
      .groups = "drop"
    ) %>%
    rename(.group_value = {{group}}) %>%
    relocate(.group_variable, .group, .group_value);
  if ( .inc_na == F ) {
    r2 = r2 %>% filter(!is.na(.group_value));
  }
  r2$.results = r2$.results %>% map(fun, ...);
  r2 = r2 %>% unnest(.results);
  
  r = bind_rows(r1, r2);
  return( r );
}

get_perf1 = function(p, filter_only = F, expand_param_value = T) {
  p2 = p %>% filter(.estimate %>% map_int(length) %>% equals(1));
  if ( filter_only ) {
    return( p2 );
  }
  
  if (expand_param_value) {
    p3 = p2 %>% unnest(c(.estimate, .param_value));
  } else {
    p3 = p2 %>% unnest(c(.estimate))
  }
  return( p3 );
}

metric_mean = function(data, v, weights, trunc = T) {
  if (is.na(weights)) {
    w = rep(1, nrow(data));
  } else {
    w = data %>% pull(!!sym(weights));
  }
  
  if ( nrow(data) > 0 ) {
    f = formula(paste(v, "~ 1"));
    m = try(lm(f, data = data, weights = w), silent = T);
    if ( m %>% inherits("try-error")) {
      r = NA;
    } else {
      r = m %>% coef() %>% as.vector();
      if ( trunc ) {
        r = r %>% pmin(1) %>% pmax(0)
      }
    }
  } else {
    r = NA;
  }
  
  return( r );
}

# dv = disease variable name (variables needs value 0 or 1)
# tv = test variable name (variables needs value 0 or 1)
binary_metric_std = function(data, dv, tv, weights = NA) {
  idv = paste0("I(1 -", dv, ")");
  itv = paste0("I(1 -", tv, ")");
  dtv = paste0("I(", dv, "*", tv, ")");
  idtv = paste0("I(", dv, "*(1 - ", tv, "))");
  n = nrow(data);
  
  se = data %>% filter((!!sym(dv)) == 1) %>% metric_mean(v = tv, weights = weights);
  sp = data %>% filter((!!sym(dv)) == 0) %>% metric_mean(v = itv, weights = weights);
  ppv = data %>% filter((!!sym(tv)) == 1) %>% metric_mean(v = dv, weights = weights);
  npv = data %>% filter((!!sym(tv)) == 0) %>% metric_mean(v = idv, weights = weights);
  air = data %>% metric_mean(v = tv, weights = weights);
  cdr = data %>% metric_mean(v = dtv, weights = weights);
  fnr = data %>% metric_mean(v = idtv, weights = weights);
  
  r1 = tibble( .n = n, .predictor = tv, .metric = "sens", .estimate = list( se ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
  r2 = tibble( .n = n, .predictor = tv, .metric = "spec", .estimate = list( sp ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
  r3 = tibble( .n = n, .predictor = tv, .metric = "ppv", .estimate = list( ppv ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
  r4 = tibble( .n = n, .predictor = tv, .metric = "npv", .estimate = list( npv ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
  r5 = tibble( .n = n, .predictor = tv, .metric = "air", .estimate = list( air ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
  r6 = tibble( .n = n, .predictor = tv, .metric = "cdr", .estimate = list( cdr ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
  r7 = tibble( .n = n, .predictor = tv, .metric = "fnr", .estimate = list( fnr ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
  r = bind_rows(r1, r2, r3, r4, r5, r6, r7);
  return( r );
}

continuous_metric_std = function(data, dv, tv, th, weights = NA) {
  data %<>%
    mutate(
      .b_tv_temp = as.integer((!!sym(tv)) >= th)
    )
  
  r = data %>% binary_metric_std(dv = dv, tv = ".b_tv_temp", weights = weights);
  return( r );
}

calib_glm_metric = function(data, pred, truth, weights = NA, link = c("logit", "log", "linear")) {
  link = match.arg(link);
  
  #print(pred)
  
  if (!is.na(weights)) {
    w = data %>% pull(all_of(weights));
    w = w / mean(w);
  } else {
    w = rep(1, nrow(data))
  }
  
  # avoid 0's and 1's as needed
  x = data %>% pull(all_of(pred));
  if (any(x %in% c(0, 1))) {
    xx = x %>% setdiff(c(0, 1)) %>% range();
    if (link == "logit") {
      ind = (x == 1);
      x[ind] = 1 - (1 - xx[2]) / 2;
    }
    
    if (link %in% c("logit", "log")) {
      ind = (x == 0);
      x[ind] = xx[1] / 2;
    }
    
    data %<>% mutate(!!sym(pred) := x);
  }
  
  data$.null = data %>% metric_mean(v = truth, weights = weights);

  if (link == "logit") {
    data %<>%
      mutate(
        .null = log(.null / (1 - .null)),
        .pred = log(!!sym(pred) / (1 - !!sym(pred)))
      );
    
    f0 = formula(glue::glue("{truth} ~ offset(log({pred} / (1 - {pred})))"));
    f1 = formula(glue::glue("{truth} ~ log({pred} / (1 - {pred}))"));
    
    m0 = try(glm(f0, data = data, family = quasibinomial(link = logit), weights = w));
    m1 = try(glm(f1, data = data, family = quasibinomial(link = logit), weights = w));
  } else if (link == "log") {
    data %<>%
      mutate(
        .null = log(.null),
        .pred = log(!!sym(pred))
      );
    
    f0 = formula(glue::glue("{truth} ~ offset(log({pred}))"));
    f1 = formula(glue::glue("{truth} ~ log({pred})"));
    
    m0 = try(glm(f0, data = data, family = quasibinomial(link = log), weights = w));
    m1 = try(glm(f1, data = data, family = quasibinomial(link = log), weights = w));
  } else {
    data %<>%
      mutate(
        .pred = !!sym(pred)
      )
    
    f0 = formula(glue::glue("{truth} ~ offset({pred})"));
    f1 = formula(glue::glue("{truth} ~ {pred}"));
    
    m0 = try(lm(f0, data = data, weights = w));
    m1 = try(lm(f1, data = data, weights = w));
  }
  
  if (inherits(m0, "try-error")) {
    const = NA_real_;
  } else {
    const = m0 %>% coef() %>% pluck(1) %>% as.vector();  
  }
  
  if (inherits(m1, "try-error")) {
    int = NA_real_;
    slope = NA_real_;
  } else {
    int = m1 %>% coef() %>% pluck(1) %>% as.vector();
    slope = m1 %>% coef() %>% pluck(2) %>% as.vector();
  }
  
  bs_null = data %>% calc_brier(ev = truth, pv = ".null")
  bs = data %>% calc_brier(ev = truth, pv = ".pred")
  ipa = 1 - bs / bs_null
  
  r1 = tibble(
    .n = nrow(data),
    .predictor = pred,
    .metric = glue::glue("brier_{link}") %>% as.character(), 
    .estimate = list(bs),
    .param = "",
    .param_value = list(NA), 
    .weighted = !is.na(weights)
  );
  r2 = r1 %>%
    mutate(
      .metric = glue::glue("ipa_{link}") %>% as.character(), 
      .estimate = list(ipa),
      .param = "null",
      .param_value = list(
        tibble(
          pred_null = data$.null[1],
          bs_null = bs_null
        )
      )
    );
  ra = bind_rows(r1, r2);
  
  r1 = tibble(
    .n = nrow(data),
    .predictor = pred,
    .metric = glue::glue("calib_const_{link}") %>% as.character(), 
    .estimate = list(const),
    .param = "",
    .param_value = list(NA), 
    .weighted = !is.na(weights)
  );
  r2 = r1 %>%
    mutate(
      .metric = glue::glue("calib_int_{link}") %>% as.character(), 
      .estimate = list(int),
    );
  r3 = r1 %>%
    mutate(
      .metric = glue::glue("calib_slope_{link}") %>% as.character(), 
      .estimate = list(slope),
    );
  
  rb = bind_rows(r1, r2, r3);
  
  r = bind_rows(ra, rb);
  
  return(r);
}


# truth must be numeric 0/1
perf_curves = function(data, pred, truth, weights=NA) {
  stopifnot( length(truth)==1 );
  x = data %>% pull(all_of(truth));
  stopifnot( x %>% is.numeric() );
  stopifnot( all( x %in% 0:1 ) );
  stopifnot( length(weights)==1 );
  
  n = data %>% nrow();
  cols = c( pred, truth );
  if ( !is.na(weights) ) {
    cols = c( cols, weights );
  }
  
  x = data %>%
    group_split(!!sym(truth)) %>%
    map( ~ .x %>% select(all_of(cols)));
  
  weighted_results = function(pred) {
    roc = PRROC::roc.curve(
      scores.class0 = x[[2]] %>% pull(all_of(pred)),
      scores.class1 = x[[1]] %>% pull(all_of(pred)),
      weights.class0 = x[[2]] %>% pull(all_of(weights)),
      weights.class1 = x[[1]] %>% pull(all_of(weights)),
      curve=T
    );
    
    pr = PRROC::pr.curve(
      scores.class0 = x[[2]] %>% pull(all_of(pred)),
      scores.class1 = x[[1]] %>% pull(all_of(pred)),
      weights.class0 = x[[2]] %>% pull(all_of(weights)),
      weights.class1 = x[[1]] %>% pull(all_of(weights)),
      curve=T
    );
    
    r1 = tibble( .n = n, .predictor = pred, .metric = "roc_curve", .curve = list( roc ), .weighted=!is.na(weights) );
    r2 = tibble( .n = n, .predictor = pred, .metric = "pr_curve", .curve = list( pr ), .weighted=!is.na(weights) );
    r = bind_rows(r1, r2);
    return( r );
  }
  
  unweighted_results = function(pred) {
    roc = PRROC::roc.curve(
      scores.class0 = x[[2]] %>% pull(all_of(pred)),
      scores.class1 = x[[1]] %>% pull(all_of(pred)),
      curve=T
    );
    
    pr = PRROC::pr.curve(
      scores.class0 = x[[2]] %>% pull(all_of(pred)),
      scores.class1 = x[[1]] %>% pull(all_of(pred)),
      curve=T
    );
    
    r1 = tibble( .predictor = pred, .metric = "roc_curve", .curve = list( roc ), .weighted=!is.na(weights) );
    r2 = tibble( .predictor = pred, .metric = "pr_curve", .curve = list( pr ), .weighted=!is.na(weights) );
    r = bind_rows(r1, r2);
    return( r );
  }
  
  if ( is.na(weights) ) {
    r = pred %>% map_dfr(unweighted_results);
  } else {
    r = pred %>% map_dfr(weighted_results);
  }
  
  return( r );
}

roc_at_spec = function(roc) {
  df = roc$curve %>%
    as_tibble(.name_repair="minimal") %>%
    set_names(c("spec", "sens", "th")) %>%
    mutate(
      spec = 1 - spec
    ) %>%
    group_by(spec) %>%
    summarize(
      across(everything(), mean),
      .groups = "drop"
    );
  sf = with( df, approxfun( spec, sens ) );
  tf = with( df, approxfun( spec, th ) );
  r = list(df = df, sens = sf, th = tf);
  return( r );
}

roc_at_sens = function(roc) {
  df = roc$curve %>%
    as_tibble(.name_repair="minimal") %>%
    set_names(c("spec", "sens", "th")) %>%
    mutate(
      spec = 1 - spec
    ) %>%
    group_by(sens) %>%
    summarize(
      across(everything(), mean),
      .groups = "drop"
    );
  sf = with( df, approxfun( sens, spec ) );
  tf = with( df, approxfun( sens, th ) );
  r = list(df = df, spec = sf, th = tf);
  return( r );
}

sens_at_spec = function(roc, spec) {
  r = roc %>% roc_at_spec();
  sens = r$sens(spec);
  return( sens );
}

spec_at_sens = function(roc, sens) {
  r = roc %>% roc_at_sens();
  spec = r$spec( sens );
  return( spec );
}

# truth must be numeric 0/1
summarize_binary_predictor = function(data, pred, truth, weights=NA) {
  stopifnot( length(truth)==1 );
  x = data %>% pull(all_of(truth));
  stopifnot( x %>% is.numeric() );
  stopifnot( all( x %in% 0:1 ) );
  stopifnot( length(weights)==1 );
  
  n = data %>% nrow();
  cols = c( pred, truth );
  if ( !is.na(weights) ) {
    cols = c( cols, weights );
  }
  
  x = data %>%
    group_split(!!sym(truth)) %>%
    map( ~ .x %>% select(all_of(cols)));
  
  weighted_results = function(pred) {
    roc = PRROC::roc.curve(
      scores.class0 = x[[2]] %>% pull(all_of(pred)),
      scores.class1 = x[[1]] %>% pull(all_of(pred)),
      weights.class0 = x[[2]] %>% pull(all_of(weights)),
      weights.class1 = x[[1]] %>% pull(all_of(weights)),
      curve=T
    );
    
    pr = PRROC::pr.curve(
      scores.class0 = x[[2]] %>% pull(all_of(pred)),
      scores.class1 = x[[1]] %>% pull(all_of(pred)),
      weights.class0 = x[[2]] %>% pull(all_of(weights)),
      weights.class1 = x[[1]] %>% pull(all_of(weights)),
      curve=T
    );
    
    r = extract_results( pred, roc, pr );
    return( r );
  }
  
  unweighted_results = function(pred) {
    roc = PRROC::roc.curve(
      scores.class0 = x[[2]] %>% pull(all_of(pred)),
      scores.class1 = x[[1]] %>% pull(all_of(pred)),
      curve=T
    );
    
    pr = PRROC::pr.curve(
      scores.class0 = x[[2]] %>% pull(all_of(pred)),
      scores.class1 = x[[1]] %>% pull(all_of(pred)),
      curve=T
    );
    
    r = extract_results( pred, roc, pr );
    return( r );
  }
  
  extract_results = function(pred, roc, pr) {
    #r1 = tibble( .n = n, .predictor = pred, .metric = "sens", .estimate = list( roc$curve[2,2] ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
    #r2 = tibble( .n = n, .predictor = pred, .metric = "spec", .estimate = list( 1 - roc$curve[2,1] ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
    r3 = tibble( .n = n, .predictor = pred, .metric = "roc_auc", .estimate = list( roc$auc ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
    r4 = tibble( .n = n, .predictor = pred, .metric = "roc_curve", .estimate = list( roc$curve ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
    r5 = tibble( .n = n, .predictor = pred, .metric = "pr_auc", .estimate = list( pr$auc.integral ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
    r6 = tibble( .n = n, .predictor = pred, .metric = "pr_curve", .estimate = list( pr$curve ), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
    
    #r = bind_rows( r1, r2, r3, r4, r5, r6 );
    r = bind_rows( r3, r4, r5, r6 );
    return( r );
  }
  
  #r1 = data %>% binary_metric_std(dv = truth, tv = pred, weights = weights);
  r1 = pred %>% map_dfr(~ data %>% binary_metric_std(dv = truth, tv = .x, weights = weights));
  if ( is.na(weights) ) {
    r2 = pred %>% map_dfr(unweighted_results);
  } else {
    r2 = pred %>% map_dfr(weighted_results);
  }
  r = bind_rows(r1, r2);
  
  return( r );
}


# truth must be numeric 0/1
summarize_continuous_predictor = function(data, pred, truth, at_sens=NA, at_spec=NA, calib = F, weights=NA) {
  stopifnot( length(truth)==1 );
  x = data %>% pull(all_of(truth));
  stopifnot( x %>% is.numeric() );
  stopifnot( all( x %in% 0:1 ) );
  stopifnot( length(weights)==1 );
  
  n = data %>% nrow();
  cols = c( pred, truth );
  if ( !is.na(weights) ) {
    cols = c( cols, weights );
  }
  
  x = data %>%
    group_split(!!sym(truth)) %>%
    map( ~ .x %>% select(all_of(cols)));
  
  weighted_results = function(pred) {
    roc = try(
        RROC::roc.curve(
        scores.class0 = x[[2]] %>% pull(all_of(pred)),
        scores.class1 = x[[1]] %>% pull(all_of(pred)),
        weights.class0 = x[[2]] %>% pull(all_of(weights)),
        weights.class1 = x[[1]] %>% pull(all_of(weights)),
        curve = T
      )
    );
    
    pr = try(
      PRROC::pr.curve(
        scores.class0 = x[[2]] %>% pull(all_of(pred)),
        scores.class1 = x[[1]] %>% pull(all_of(pred)),
        weights.class0 = x[[2]] %>% pull(all_of(weights)),
        weights.class1 = x[[1]] %>% pull(all_of(weights)),
        curve = T
      )
    );
    
    r = extract_results( pred, roc, pr );
    return( r );
  }
  
  unweighted_results = function(pred) {
    roc = try(
      PRROC::roc.curve(
        scores.class0 = x[[2]] %>% pull(all_of(pred)),
        scores.class1 = x[[1]] %>% pull(all_of(pred)),
        curve = T
      )
    );
    
    pr = try(
      PRROC::pr.curve(
        scores.class0 = x[[2]] %>% pull(all_of(pred)),
        scores.class1 = x[[1]] %>% pull(all_of(pred)),
        curve = T
      )
    );
    
    r = extract_results( pred, roc, pr );
    return( r );
  }
  
  extract_results = function(pred, roc, pr) {
    if (!inherits(roc, "try-error") & any(!is.na(at_spec))) {
      r1 = at_spec %>%
        imap_dfr(
          function(.x, .y) {
            rx = roc %>% roc_at_spec();
            th = rx$th(.x);
            r1 = tibble(
              .n = n, 
              .predictor = pred,
              .metric = "sens",
              #.estimate = list( sens_at_spec( roc, .x ) ),
              .estimate = list( rx$sens(.x) ),
              .param = .y,
              .param_value = list(tibble(at_spec = .x, at_th = th)),
              .weighted=!is.na(weights)
            );
            r2 = tibble(
              .n = n,
              .predictor = pred,
              .metric = "th",
              .estimate = list( rx$th(.x) ),
              .param = .y,
              .param_value = list(tibble(at_spec = .x)),
              .weighted=!is.na(weights)
            );
            r3 = data %>% continuous_metric_std(dv = truth, tv = pred, th = th, weights = weights);
            r3$.predictor = pred;
            r3$.param = .y;
            r3$.param_value = r1$.param_value %>% rep(nrow(r3));
            r3 = r3 %>% filter(.metric != "spec")
            #r = bind_rows(r1, r2, r3);
            r = bind_rows(r2, r3);
            return( r );
          }
        );
    } else {
      r1 = NULL;
    }
    
    if (!inherits(roc, "try-error") & any(!is.na(at_sens))) {
      r2 = at_sens %>%
        imap_dfr(
          function(.x, .y) {
            rx = roc %>% roc_at_sens();
            th = rx$th(.x);
            r1 = tibble(
              .n = n, 
              .predictor = pred,
              .metric = "spec",
              #.estimate = list( spec_at_sens( roc, .x ) ),
              .estimate = list(rx$spec(.x) ),
              .param = .y,
              .param_value = list(tibble(at_sens = .x, at_th = th)),
              .weighted=!is.na(weights)
            );
            r2 = tibble(
              .n = n, 
              .predictor = pred,
              .metric = "th",
              .estimate = list( rx$th(.x) ),
              .param = .y,
              .param_value = list(tibble(at_sens = .x)),
              .weighted=!is.na(weights)
            );
            r3 = data %>% continuous_metric_std(dv = truth, tv = pred, th = th, weights = weights);
            r3$.predictor = pred;
            r3$.param = .y;
            r3$.param_value = r1$.param_value %>% rep(nrow(r3));
            r3 = r3 %>% filter(.metric != "sens")
            #r = bind_rows(r1, r2, r3);
            r = bind_rows(r2, r3);
            return( r );
          }
        );
    } else {
      r2 = NULL;
    }
    
    if (inherits(roc, "try-error")) {
      r3 = tibble( .n = n, .predictor = pred, .metric = "roc_auc", .estimate = list(NA_real_), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
      r4 = NULL;
    } else {
      r3 = tibble( .n = n, .predictor = pred, .metric = "roc_auc", .estimate = list(roc$auc), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
      r4 = tibble( .n = n, .predictor = pred, .metric = "roc_curve", .estimate = list(roc$curve), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
    }
    
    if (inherits(pr, "try-error")) {
      r5 = tibble( .n = n, .predictor = pred, .metric = "pr_auc", .estimate = list(NA_real_), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
      r6 = NULL;
    } else {
      r5 = tibble( .n = n, .predictor = pred, .metric = "pr_auc", .estimate = list(pr$auc.integral), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
      r6 = tibble( .n = n, .predictor = pred, .metric = "pr_curve", .estimate = list(pr$curve), .param = "", .param_value = list(NA), .weighted=!is.na(weights) );
    }
    
    r = bind_rows( r1, r2, r3, r4, r5, r6 );
    return( r );
  }
  
  if ( is.na(weights) ) {
    r = pred %>% map_dfr(unweighted_results);
  } else {
    r = pred %>% map_dfr(weighted_results);
  }
  
  if (calib) {
    r1 = pred %>% map_dfr(calib_glm_metric, data = data, truth = truth, weights = weights, link = "logit");
    r2 = pred %>% map_dfr(calib_glm_metric, data = data, truth = truth, weights = weights, link = "log");
    r3 = pred %>% map_dfr(calib_glm_metric, data = data, truth = truth, weights = weights, link = "linear");
    r = bind_rows(r, r1, r2, r3);
  }
  
  return( r );
}

# truth must be numeric 0/1
summarize_continuous_predictor_at_rad = function(data, rad, pred, truth, at_sens = NA, at_spec = NA, calib = F, weights = NA) {
  r1 = data %>% summarize_binary_predictor(pred = rad, truth = truth, weights = weights);
  
  rad_at_sens = list("sens, rad" = r1 %>% filter(.metric == "sens") %>% pull(.estimate) %>% pluck(1));
  rad_at_spec = list("spec, rad" = r1 %>% filter(.metric == "spec") %>% pull(.estimate) %>% pluck(1));
  
  r1a = r1 %>% filter(.metric %in% c("roc_auc", "pr_auc", "roc_curve", "pr_curve"));
  r1b = r1 %>%
    filter(!.metric %in% r1a$.metric) %>%
    mutate(.param = "sens, rad") %>%
    filter(.metric != "sens");
  r1c = r1 %>%
    filter(!.metric %in% r1a$.metric) %>%
    mutate(.param = "spec, rad") %>%
    filter(.metric != "spec");
  r1 = bind_rows(r1a, r1b, r1c);
  
  if ( all(is.na(at_sens)) ) {
    at_sens = rad_at_sens;
  } else {
    at_sens = at_sens %>% append(rad_at_sens);
  }
  
  if ( all(is.na(at_spec)) ) {
    at_spec = rad_at_spec;
  } else {
    at_spec = at_spec %>% append(rad_at_spec);
  }
  
  r2 = data %>% summarize_continuous_predictor(pred = pred, truth = truth, weights = weights, at_sens = at_sens, at_spec = at_spec, calib = calib);
  
  r = bind_rows(r1, r2);
  return( r );
}

summarize_continuous_predictor_for_surv = function(data, pred, truth, calib = F) {
  stopifnot(length(truth) == 1);
  f = formula(str_glue("~ {truth}"));
  s = model.frame(f, data)[,1];
  stopifnot(inherits(s, "Surv"));
  
  n = data %>% nrow();
  stopifnot(n == nrow(s));
  
  fv = f %>% all.vars();
  stopifnot(length(fv) == 2);
  
  tv = fv[1];
  ev = fv[2];
  
  r1 = data %>%
    calc_cindex(
      tv = tv,
      ev = ev,
      pv = pred
    );
  
  r2 = tibble(.n = n, .predictor = pred, .metric = "cindex", .estimate = list(r1), .param = "", .param_value = list(NA), .weighted = F);
  
  return(r2);  
}


