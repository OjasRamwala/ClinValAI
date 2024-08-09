rm( list=ls() );
source("R-include/fun_boot.R", chdir = T);
source("R-include/fun_perf.R", chdir = T);
library(magrittr);
library(tidyverse);
library(survival);


file_in = list(
  data = str_glue("Data/nwscore-exam-data.csv")
);

file_out = list(
  bs_slim = str_glue("Output/Data/02-bs-slim.rds"),
  bs_slim3 = str_glue("Output/Data/02-bs-slim3.rds"),
  bd_roc = str_glue("Output/Data/02-bd-roc.rds"),
  rx_boot = str_glue("Output/Data/02-rx-boot.rds")
);


###
# Data
###

if (1) {
  data = file_in$data %>% read_csv();
  
  data2 = data %>% 
    group_by(sid) %>%
    mutate(
      b_bc_5y_sid = b_bc_5y %>% max()
    ) %>%
    ungroup() %>%
    mutate(
      b_bc_5y_sid = b_bc_5y_sid %>% factor()
    );
  
  # exclude cancers within 6 months
  data3 = data2 %>%
    filter(time_bc_5y >= 365/2);
  
  # exclude cancers within 12 months
  data4 = data2 %>%
    filter(time_bc_5y >= 365);
  
  dim(data2)
  data2_nested = data2 %>%
    nest(.nested_data = !c(sid, b_bc_5y_sid));
  dim(data2_nested)
  
  dim(data3)
  data3_nested = data3 %>%
    nest(.nested_data = !c(sid, b_bc_5y_sid));
  dim(data3_nested)
  
  dim(data4)
  data4_nested = data4 %>%
    nest(.nested_data = !c(sid, b_bc_5y_sid));
  dim(data4_nested)
}


###
# Bootstraps
###

if (1) {
  t1a = Sys.time();
  print("Generating bootstrap samples...");

  R = 999;
  
  fun = function(data_nested, .stratified, .subset) {
    set.seed(42);
    if (.stratified) {
      bs_slim = data_nested %>%
        rsample::bootstraps(
          times = R,
          strata = b_bc_5y_sid,
          apparent = T
        );
    } else {
      bs_slim = data_nested %>%
        rsample::bootstraps(
          times = R,
          apparent = T
        );
    }
    
    bs_slim %<>%
      get_rset_skeleton() %>%
      add_column(.stratified = .stratified) %>%
      add_column(.subset = .subset)

    return(bs_slim);
  }
  
  bs_slim_1 = data2_nested %>% fun(.stratified = T, .subset = "all");
  print("Finished 1 of 6...");
  bs_slim_2 = data2_nested %>% fun(.stratified = F, .subset = "all");
  print("Finished 2 of 6...");
  bs_slim_3 = data3_nested %>% fun(.stratified = T, .subset = "ex6m");
  print("Finished 3 of 6...");
  bs_slim_4 = data3_nested %>% fun(.stratified = F, .subset = "ex6m");
  print("Finished 4 of 6...");
  bs_slim_5 = data3_nested %>% fun(.stratified = T, .subset = "ex1y");
  print("Finished 5 of 6...");
  bs_slim_6 = data3_nested %>% fun(.stratified = F, .subset = "ex1y");
  print("Finished 6 of 6...");
  
  
  bs_slim = bind_rows(bs_slim_1, bs_slim_2, bs_slim_3, bs_slim_4, bs_slim_5, bs_slim_6);
  
  bs_slim %<>%
    set_class(class(bs_slim_1)) %>%
    set_attributes(attributes(bs_slim_1)) %>%
    set_attr("row.names", 1:nrow(bs_slim));
  
  bs_slim %>% saveRDS(file = file_out$bs_slim);
  
  meat_all = data2_nested;
  meat_ex6m = data3_nested;
  meat_ex1y = data4_nested;
  
  stopifnot(meat_all %>% is_data_nested());
  stopifnot(meat_ex6m %>% is_data_nested());
  stopifnot(meat_ex1y %>% is_data_nested());

  t1b = Sys.time();
  print(str_glue("Took {round(difftime(t1b, t1a, units = 'secs'), 0)} seconds"));
} else {
  t1a = Sys.time();
  print("Loading bootstrap samples...");
  
  bs_slim = file_out$bs_slim %>% readRDS();
  
  meat_all = data2_nested;
  meat_ex6m = data3_nested;
  meat_ex1y = data4_nested;
  
  stopifnot(meat_all %>% is_data_nested());
  stopifnot(meat_ex6m %>% is_data_nested());
  stopifnot(meat_ex1y %>% is_data_nested());
  
  t1b = Sys.time();
  print(str_glue("Took {round(difftime(t1b, t1a, units = 'mins'), 0)} minutes"));
}


###
# Parameters
###

if (1) {
  rx = expand_grid(
    truth = c(paste0("b_bc_", 1:5, "y"), "Surv(time_bc_5y, b_bc_5y)"),
    pred = paste0("mirai_", 1:5, "y"),
    level = c("e")
  ) %>%
    mutate(
      tp = truth %>% str_extract("[0-9]y"),
      with_calib = grepl("^b_bc_[0-9]y$", truth)
    ) %>%
    filter(map2_lgl(tp, pred, grepl)) %>%
    expand_grid(
      grouped = c(F, T)
    ) %>%
    filter(
      tp == "5y" | !grouped
    );
  
  gv = c("age_cat", "race_cat2", "b_dens");
  gv
  
  bs_slim2 = bs_slim %>%
    expand_grid(rx);
  
  bs_slim2 %<>%
    set_class(class(bs_slim)) %>%
    set_attributes(attributes(bs_slim)) %>%
    set_attr("names", names(bs_slim2)) %>%
    set_attr("row.names", 1:nrow(bs_slim2));
}


###
# Slurm
###

if (1) {
  t2a = Sys.time();
  print("Bootstrapping via slurm...");
  
  slurm_fun = function(splits, id, .stratified, .subset, truth, pred, level, tp, with_calib, grouped) {
    print(str_glue("# {id}, {.stratified}, {.subset}, {truth}, {pred}, {level}, {tp}, {with_calib}, {grouped}"));
    stopifnot(grepl("^(b_|Surv)", truth));
    stopifnot(.subset %in% c("all", "ex6m", "ex1y"));
    stopifnot(level %in% c("e"));
    
    if (.subset == "all") {
      meat = meat_all;
    } else if (.subset == "ex6m") {
      meat = meat_ex6m;
    } else if (.subset == "ex1y") {
      meat = meat_ex1y;
    }
    
    data = splits %>%
      confirm_rset_meat_on_rib(m = meat) %>%
      rsample::analysis() %>%
      confirm_data_unnested();
    
    if (grepl("^Surv", truth)) {
      print("## Summarize survival outcome");
      sf = summarize_continuous_predictor_for_surv
    } else {
      print("## Summarize binary outcome");
      sf = summarize_continuous_predictor
    }
    
    if (!grouped) {
      print("## Summarize performance overall");
      rx = data %>%
        sf(
          pred = pred,
          truth = truth,
          calib = with_calib
        );
      
      rx2 = rx %>%
        filter(!grepl("^pr_", .metric));
      
      if (!.stratified) {
        rx2 %<>%
          get_perf1(filter_only = T);
      }
      
      print("## Finished");
      return(rx2);
    }
    
    fun = function(gv) {
      print(str_glue("### {gv}"));
      data %>%
        grouped_summary(
          group = !!sym(gv),
          fun = sf,
          pred = pred,
          truth = truth,
          calib = with_calib,
          .inc_na = F
        ) %>%
        mutate(
          .group_value = .group_value %>% as.character()
        )
    }
    print("## Summarize performance by group");
    rx = gv %>% map_dfr(fun);
    rx2 = rx %<>% 
      get_perf1(filter_only = T) %>%
      filter(!grepl("^pr_", .metric));
    print("## Finished");
    
    return(rx2);
  }
  
  if (0) {
    res = bs_slim2 %>%
      filter(id == "Apparent") %>%
      filter(tp == "5y") %>%
      #filter(with_calib) %>%
      pmap(slurm_fun);
    res
  }
  
  jn = "mirai_20240724";
  jn
  
  sjob = rslurm::slurm_apply(
    f = slurm_fun,
    params = bs_slim2,
    global_objects = c(
      (function() {source("R-include/fun_boot.R", local = T); return(ls())})(),
      (function() {source("R-include/fun_perf.R", local = T); return(ls())})(),
      "meat_all",
      "meat_ex6m",
      "meat_ex1y",
      "gv"
    ),
    pkgs = c(
      "magrittr",
      "tidyverse",
      "survival"
    ),
    jobname = jn,
    nodes = 500,
    cpus_per_node = 1,
    preschedule_cores = F,
    slurm_options = list(
      constraint = "gizmok"
    ),
    submit = T
  )
  
  sjob %>% saveRDS(file = paste0("slurm_job_", jn, ".rds"));
  #sjob = readRDS(file = paste0("slurm_job_", jn, ".rds"));
  
  s = sjob %>% rslurm::get_job_status()
  s$completed
  s$queue %>% as_tibble()
  
  s$log %>% map_int(nchar) %>% sort()
  s$log[1]
  s$log[87]
  
  print("Waiting for slurm...");
  sout = sjob %>% rslurm::get_slurm_out(wait = T);

  if (0) {
    # clean up
    sjob %>% rslurm::cancel_slurm()
    sjob %>% rslurm::cleanup_files(wait = F)
  }
  
  print("Integrating results...");
  bs_slim3 = bs_slim2 %>% 
    add_column(perf = sout %>% set_names(nm = NULL));
  bs_slim3
  
  bs_slim3 %>%
    map(~ .x %>% object.size() %>% divide_by(1e6))
  
  bs_slim3 %>% 
    select(-splits) %>%
    saveRDS(file = file_out$bs_slim3);

  t2b = Sys.time();
  print(str_glue("Took {round(difftime(t2b, t2a, units = 'mins'), 0)} minutes"));
} else {
  t2a = Sys.time();
  print("Loading bootstrap results...");
  
  bs_slim3 = file_out$bs_slim3 %>% readRDS();
  
  t2b = Sys.time();
  print(str_glue("Took {round(difftime(t2b, t2a, units = 'mins'), 0)} minutes"));
}



###
# Summarize bootstrap results
###

if (1) {
  t3a = Sys.time();
  print("Aggregating bootstrap results...");
  
  if (!"splits" %in% names(bs_slim3)) {
    bs_slim3 %<>%
      left_join(
        bs_slim,
        by = c("id", ".stratified", ".subset")
      ) %>%
      relocate(splits);
  }

  bd_roc = bs_slim3 %>%
    select(-splits) %>%
    filter(!grouped) %>%
    unnest(perf) %>%
    filter(.metric == "roc_curve")
  bd_roc %>% map(~ .x %>% object.size() %>% divide_by(1e6))
  
  bd_roc_app = bd_roc %>%
    filter(id == "Apparent") %>%
    mutate(
      .estimate = .estimate %>%
        map(
          ~ .x %>%
            as_tibble(.name_repair="minimal") %>%
            set_names(c("spec", "sens", "th")) %>%
            mutate(
              spec = 1 - spec
            ) %>%
            group_by(spec) %>%
            summarize(
              across(everything(), mean),
              .groups = "drop"
            ) 
        )
    )

  bd_all = bs_slim3 %>%
    filter(!grouped) %>%
    unnest(perf) %>%
    get_perf1(expand_param_value = F);
  bd_all %>% map(~ .x %>% object.size() %>% divide_by(1e6))
  
  bd_group = bs_slim3 %>%
    filter(grouped) %>%
    unnest(perf) %>%
    get_perf1(expand_param_value = F);
  bd_group %>% map(~ .x %>% object.size() %>% divide_by(1e6))
  
  null_value_wg = bd_all %>%
    distinct(.metric) %>%
    mutate(
      value = case_when(
        .metric %in% c("roc_auc", "sens", "spec", "cindex") ~ 0.5,
        grepl("calib_slope", .metric) ~ 1,
        grepl("calib_(const|int)", .metric) ~ 0,
        grepl("^ipa_", .metric) ~ 0,
        T ~ NA_real_
      )
    ) %>%
    filter(!is.na(value)) %>%
    deframe();
  null_value_wg
  
  # compare predictors overall
  pred_comp_all = bd_all %>% get_pred_comp();
  pred_comp_all = pred_comp_all %>% bootstrap_pred_diff_dist(bd_all, gv = c(".stratified", ".subset", "level"));
  diff_bd_all = pred_comp_all$.boot_diff_dist %>% bind_rows();
  null_value_wg_diff = pred_comp_all %>% get_diff_null_values();
  null_value_wg_diff
  
  # compare predictors between groups 
  group_comp = bd_group %>% 
    group_by(.group_variable) %>%
    summarize(
      x = list(pick(everything()) %>% get_group_comp()),
      .groups = "drop"
    ) %>%
    unnest(x);
  group_comp = group_comp %>% bootstrap_group_diff_dist(bd = bd_group, gv = c(".stratified", ".subset", "level"));
  bd_group_bw = group_comp$.boot_diff_dist %>% bind_rows();
  null_value_bg = group_comp %>% get_diff_null_values();
  null_value_bg
  
  alpha = 0.05;
  na_rm = T;
  
  bd_all %>%
    filter(.metric == "brier_linear", .predictor == "mirai_1y", .param == "", !.weighted, !.stratified, .subset == "all")
  
  r1 = bd_all %>% bootstrap_pred_est(alpha = alpha, na_rm = na_rm, null_value = null_value_wg);
  r2 = diff_bd_all %>% bootstrap_pred_est(alpha = alpha, na_rm = na_rm, null_value = null_value_wg_diff);
  
  xtabs( ~ .metric + .predictor + .param, r1)
  xtabs( ~ .metric + .predictor + .param, r2)
  
  # within group
  r3 = bd_group %>% bootstrap_group_pred_est(alpha = alpha, na_rm = na_rm, null_value = null_value_wg);
  
  # between group
  r5 = bd_group_bw %>% bootstrap_group_pred_est(alpha = alpha, na_rm = na_rm, null_value = null_value_bg);

  rx_boot = list(
    bd_all = bd_all %>% select(-splits),
    r_all = r1,
    r_diff_all = r2,
    bd_group = bd_group %>% select(-splits),
    r_wg = r3,
    r_bw = r5
  );
  rx_boot %>% map(~ .x %>% object.size() %>% divide_by(1e6))
  
  rx_boot %>% saveRDS(file = file_out$rx_boot);
  bd_roc_app %>% saveRDS(file = file_out$bd_roc);
  
  t3b = Sys.time();
  print(str_glue("Took {round(difftime(t3b, t3a, units = 'mins'), 0)} minutes"));
}



