rm( list=ls() );
library(magrittr);
library(tidyverse);
library(ggh4x);
library(patchwork);


file_in = list(
  data = str_glue("Data/nwscore-exam-data.csv"),
  bd_roc = str_glue("Output/Data/02-bd-roc.rds"),
  rx_boot = str_glue("Output/Data/02-rx-boot.rds")
);

file_out = list(
  tab2 = "Output/Tables/table2.csv",
  tab3 = "Output/Tables/table3.csv",
  fig7 = "Output/Figures/fig7.svg",
  fig8 = "Output/Figures/fig8.svg",
  fig9 = "Output/Figures/fig9.svg"
);



###
# Data
###

if (1) {
  data = file_in$data %>% read_csv();
  
  bd_roc = file_in$bd_roc %>% readRDS();
  
  rx_boot = file_in$rx_boot %>% readRDS();
  
  bd_all = rx_boot$bd_all;
  bd_group = rx_boot$bd_group;
  
  r_all = rx_boot$r_all;
  r_diff_all = rx_boot$r_diff_all;
  r_wg = rx_boot$r_wg;
  r_bw = rx_boot$r_bw;
}



###
# Theme
###

if (1) {
  theme_text_size = 10;
  
  theme_main = theme_bw() +
    theme(
      text = element_text(size = theme_text_size),
      axis.text = element_text(size = theme_text_size, color = 1),
      axis.title = element_text(size = theme_text_size, color = 1, face = "plain"),
      axis.title.x = element_text(margin = margin(t = 10)), 
      axis.title.y = element_text(margin = margin(r = 10)),
      legend.text = element_text(size = theme_text_size, color = 1),
      strip.text = element_text(size = theme_text_size, color = 1, face = "plain"),
      panel.grid = element_blank(),
      plot.title = element_text(size = theme_text_size, color = 1, face = "bold"),
      plot.title.position = "plot",
      plot.caption = element_text(size = theme_text_size, color = 1, face = "bold"),
      plot.caption.position = "plot",
      legend.position = "top"
    );
  
  theme_set(
    theme_main
  )
}



###
# AUC
###

df = r_all %>%
  filter(.metric %in% c("roc_auc", "cindex")) %>%
  filter(.stratified) %>%
  filter(ci_type == "Percentile") %>%
  mutate(
    tp = case_when(
      .metric == "cindex" ~ "c",
      T ~ .predictor %>% str_replace("^mirai_", "")
    ),
    tp2 = tp %>%
      fct_relevel("c", after = Inf) %>%
      fct_relabel(
        ~ case_when(
          .x == "c" ~ "C-Index",
          TRUE ~ .x %>% str_replace("y", "") %>% paste0(., "-Year AUC")
        )
      ),
    level2 = level %>%
      factor(levels = c("p", "e")) %>%
      fct_recode(
        "Patients" = "p",
        "Exams" = "e"
      ),
    .subset2 = .subset %>%
      factor(levels = c("all", "ex6m", "ex1y")) %>%
      fct_recode(
        "All" = "all",
        "Ex. Cancer\nWithin 6 Months" = "ex6m",
        "Ex. Cancer\nWithin 1 Year" = "ex1y"
      ),

  )

df2 = df %>%
  filter(level == "e") %>%
  filter(.subset %in% c("all", "ex6m")) %>%
  mutate(
    .subset3 = .subset %>%
      fct_recode(
        "All Exams" = "all",
        "Excluding Cancers Within 6 Months" = "ex6m"
      )
  )

tx2 = df2 %>%
  filter(tp %in% c("1y", "5y", "c")) %>%
  transmute(
    .subset, 
    name = tp %>% factor(),
    value = sprintf("%.2f (%.2f, %.2f)", estimate, lower, upper)
  ) %>%
  pivot_wider(names_sort = T)

 
gg_auc = df2 %>%
  ggplot(aes(x = tp2, y = estimate, color = .subset3)) +
  scale_y_continuous(
    limits = c(0.5, 1)
  ) +
  ggokabeito::scale_color_okabe_ito(order = c(1, 2)) +
  labs(
    y = "AUC or C-Index",
    color = "",
    title = "A"
  ) +
  theme(
    axis.title.x = element_blank(),
    axis.text.x = element_text(angle = 20, hjust = 1),
    legend.position = "bottom"
  ) +
  geom_pointrange(
    aes(ymin = lower, ymax = upper),
    position = position_dodge(width = 0.5),
    size = 0.4
  )


###
# Table 2: NW-SCORE AUC and c-index
###

tx2 %>% write_csv(file = file_out$tab2);


###
# ROC
###

df = bd_roc %>%
  filter(.stratified) %>%
  select(-c(id, .stratified, with_calib, grouped, .metric, .param, .param_value, .weighted)) %>%
  unnest(.estimate) %>%
  mutate(
    tp2 = tp %>% str_replace("y", "") %>% paste0(., "-Year"),
    level2 = level %>%
      factor(levels = c("p", "e")) %>%
      fct_recode(
        "Patients" = "p",
        "Exams" = "e"
      ),
    .subset2 = .subset %>%
      factor(levels = c("all", "ex6m", "ex1y")) %>%
      fct_recode(
        "All" = "all",
        "Ex. Cancer\nWithin 6 Months" = "ex6m",
        "Ex. Cancer\nWithin 1 Year" = "ex1y"
      )
  );

df2 = df %>%
  filter(level == "e") %>%
  filter(.subset %in% c("all", "ex6m")) %>%
  mutate(
    .subset3 = .subset %>%
      fct_recode(
        "All Exams" = "all",
        "Excluding Cancers Within 6 Months" = "ex6m"
      )
  )

plot_roc = function(df) {
  df %>%
    ggplot(aes(x = spec, y = sens)) +
    coord_fixed() +
    scale_x_continuous(
      trans = "reverse",
      labels = scales::percent
    ) +
    scale_y_continuous(
      labels = scales::percent
    ) +
    labs(
      x = "Specificity (%)",
      y = "Sensitivity (%)",
      color = ""
    ) +
    theme(
      panel.spacing = unit(0.75, "lines")
    ) +
    geom_abline(
      linetype = 2,
      intercept = 1,
      slope = 1
    ) +
    geom_step(
      aes(color = tp2),
      linewidth = 1
    )
}

gg_roc_1 = df2 %>% filter(.subset == "all") %>% plot_roc() + ggtitle("B");
gg_roc_2 = df2 %>% filter(.subset == "ex6m") %>% plot_roc() + ggtitle("C");

gg_auc_roc = gg_auc +
  gg_roc_1 + 
  gg_roc_2 +
  plot_layout(
    guides = "collect"
  ) &
  theme(
    legend.position = "bottom"
  )


###
# Figure 7: AUC and ROC
###

file_out$fig7 %>% svg(width = 8.5, height = 3.5)
print(gg_auc_roc)
dev.off()



###
# Figure 8: Performance in subgroups
###

df = r_wg %>%
  filter(.stratified) %>%
  filter(.metric == "cindex") %>%
  #filter(.metric == "roc_auc", .predictor == "mirai_5y") %>%
  filter(ci_type == "Percentile") %>%
  mutate(
    .group_variable2 = .group_variable %>%
      fct_relevel(
        "age_cat",
        "race_cat2"
      ),
    .group2 = .group %>%
      fct_inorder() %>%
      fct_recode(
        "Dense Breasts" = "b_dens = 1",
        "Non-dense Breasts" = "b_dens = 0"
      ) %>%
      fct_relabel(
        ~ case_when(
          grepl("race", .x) ~ .x %>% str_replace("^race_cat2 = ", "") %>% paste("Race"),
          grepl("age", .x) ~ .x %>% str_replace("age_cat = ", "Age "),
          T ~ .x
        )
      ) %>%
      fct_relevel(
        "Unknown Race",
        "Other Race",
        #"Age 70-79",
        #"Age 60-69",
        #"Age 50-59",
        #"Age 40-49",
        #"Post-Menopause"
      ),
    level2 = level %>%
      factor(levels = c("p", "e")) %>%
      fct_recode(
        "Patients" = "p",
        "Exams" = "e"
      ),
    .subset2 = .subset %>%
      factor(levels = c("all", "ex6m", "ex1y")) %>%
      fct_recode(
        "All" = "all",
        "Ex. Cancer\nWithin 6 Months" = "ex6m",
        "Ex. Cancer\nWithin 1 Year" = "ex1y"
      )
  ) %>%
  filter(!.group2 %in% c("Other Race", "Unknown Race"))

# comparisons of the c-index between groups
r_bw %>%
  semi_join(
    df,
    by = c(".metric", ".predictor", ".stratified", ".subset", "level", ".group_variable", "ci_type")
  ) %>%
  filter(p < 0.1) %>%
  filter(!grepl("Unknown", .group)) %>%
  filter(level == "e") %>%
  select(.subset, level, .group, estimate, lower, upper, p)


df2 = df %>%
  filter(level == "e") %>%
  filter(.subset %in% c("all", "ex6m")) %>%
  mutate(
    .subset3 = .subset %>%
      factor(levels = c("all", "ex6m")) %>%
      fct_recode(
        "All Exams" = "all",
        "Excluding Cancers\nWithin 6 Months" = "ex6m"
      )
  )

gg_subgroups = df2 %>%
  ggplot(aes(y = estimate, x = .group2, color = .subset3)) +
  facet_nested(
    cols = vars(.group_variable2),
    scales = "free_x",
    space = "free_x",
    strip = strip_nested(size = "variable")
  ) +
  scale_y_continuous(
    limits = c(0.4, 1)
  ) +
  ggokabeito::scale_color_okabe_ito(order = c(1, 2)) +
  labs(
    y = "C-index",
    #y = "5-Year AUC",
    color = ""
  ) +
  theme(
    strip.background.x = element_blank(),
    strip.text.x = element_blank(),
    axis.title.x = element_blank(),
    axis.text.x = element_text(angle = 20, hjust = 1),
    legend.position = "right"
  ) +
  geom_hline(
    yintercept = 0.5,
    linetype = 2
  ) +
  geom_pointrange(
    aes(ymin = lower, ymax = upper),
    position = position_dodge(width = 0.45),
    size = 0.4
  )

file_out$fig8 %>% svg(width = 6.83, height = 2)
print(gg_subgroups)
dev.off()


###
# Figure 9: Calibration plot
###

fun = function(b_bc, sid, level) {
  if (level == "p" | length(unique(b_bc)) == 1) {
    den = b_bc %>% length();
    num = b_bc %>% sum();
    r = binom.test(num, den);
    r2 = r %>% broom::tidy();
  } else if (level == "e") {
    r = geepack::geeglm(b_bc ~ 1, id = sid);
    r2 = r %>% broom::tidy(conf.int = T);
  }
  
  r2 %<>%
    transmute(
      b_bc_lower = conf.low %>% pmax(0),
      b_bc_upper = conf.high %>% pmin(1)
    );
  
  return(r2);
}

df = data %>%
  select(sid, nwsimagingid, matches("^b_bc_"), matches("^time_bc_"), matches("^mirai_")) %>%
  pivot_longer(matches("^(b_bc|time_bc|mirai)_"), names_pattern = "^(.+)_([0-9]y)$", names_to = c("name", "tp")) %>%
  pivot_wider() %>%
  mutate(
    level = "e"
  ) %>%
  mutate(
    .subset = "all"
  ) %>%
  bind_rows(
    .,
    filter(., time_bc >= 365/2) %>%
      mutate(
        .subset = "ex6m"
      ),
    filter(., time_bc >= 365) %>%
      mutate(
        .subset = "ex1y"
      )
  ) %>%
  expand_grid(
    nq = c(10)
  ) %>%
  group_by(level, .subset, tp, nq) %>%
  mutate(
    mirai_q = mirai %>% cut_number(n = nq[1])
  ) %>%
  group_by(level, .subset, tp, nq, mirai_q) %>%
  arrange(sid) %>%
  summarize(
    mirai = mirai %>% mean(),
    x = fun(b_bc, sid, level[1]) %>% list(),
    b_bc = b_bc %>% mean(),
    .groups = "drop"
  ) %>%
  unnest(x) %>%
  arrange(level, .subset, tp, nq, mirai_q) %>%
  group_by(level, .subset, tp, nq) %>%
  mutate(
    mirai_qn = row_number()
  ) %>%
  ungroup() %>%
  mutate(
    tp2 = tp %>% str_replace("y", "") %>% paste0(., "-Year"),
    level2 = level %>%
      factor(levels = c("p", "e")) %>%
      fct_recode(
        "Patients" = "p",
        "Exams" = "e"
      ),
    .subset2 = .subset %>%
      factor(levels = c("all", "ex6m", "ex1y")) %>%
      fct_recode(
        "All" = "all",
        "Ex. Cancer\nWithin 6 Months" = "ex6m",
        "Ex. Cancer\nWithin 1 Year" = "ex1y"
      )
  )

df3 = df %>%
  filter(level == "e") %>%
  filter(.subset %in% c("all"));

xy_lim = df3 %>%
  summarize(
    x = pmax(max(mirai), max(b_bc_upper))
  ) %>%
  pull(x)

gg_calib = df3 %>%
  ggplot(aes(x = 100*mirai, y = 100*b_bc)) +
  facet_nested(
    cols = vars(tp2)
  ) +
  coord_fixed() +
  scale_x_continuous(
    #trans = "log10"
    limits = c(0, 100 * xy_lim)
  ) +
  scale_y_continuous(
    #trans = "log10"
    limits = c(0, 100 * xy_lim)
  ) +
  labs(
    x = "MIRAI Predicted Risk Decile (%)",
    y = "Observed Risk\nof Breast Cancer (%)"
  ) +
  geom_abline(
    linetype = 2
  ) +
  geom_pointrange(
    aes(ymin = 100*b_bc_lower, ymax = 100*b_bc_upper),
    size = 0.2,
    #alpha = 0.5
  )
gg_calib


file_out$fig9 %>% svg(width = 6.83, height = 2)
print(gg_calib)
dev.off()


###
# Table 3: Calibration statistics
###

df = r_all %>%
  filter(!.stratified) %>%
  filter(grepl("^(calib|ipa)", .metric)) %>%
  filter(grepl("const|slope|ipa", .metric)) %>%
  filter(grepl("linear", .metric)) %>%
  filter(ci_type == "Percentile") %>%
  select(-c(.param, .weighted, .stratified, n_bootstraps)) %>%
  mutate(
    tp = .predictor %>% str_replace("^mirai_", ""),
    tp2 = tp %>% str_replace("y", "") %>% paste0(., "-Year"),
    level2 = level %>%
      factor(levels = c("p", "e")) %>%
      fct_recode(
        "Patients" = "p",
        "Exams" = "e"
      ),
    .subset2 = .subset %>%
      factor(levels = c("all", "ex6m", "ex1y")) %>%
      fct_recode(
        "All" = "all",
        "Ex. Cancer\nWithin 6 Months" = "ex6m",
        "Ex. Cancer\nWithin 1 Year" = "ex1y"
      )
  )

tx3 = df %>%
  filter(.metric %in% c("calib_const_linear", "calib_slope_linear")) %>%
  filter(level == "e") %>%
  filter(.subset != "ex1y") %>%
  transmute(
    .metric = .metric %>% str_split("_") %>% map_chr(nth, 2),
    .subset,
    tp,
    estimate,
    lower,
    upper,
    p
  ) %>%
  mutate(
    across(c(estimate, lower, upper), ~ if_else(.metric == "const", 100 * .x, .x)),
    est = sprintf("%.2f", estimate),
    ci = sprintf("(%.2f, %.2f)", lower, upper),
    p = sprintf("%.3f", p),
    blank = ""
  ) %>%
  select(-c(estimate, lower, upper)) %>%
  pivot_wider(names_from = c(".metric"), values_from = c("est", "ci", "p", "blank"), names_vary = "slowest") %>%
  pivot_wider(names_from = ".subset", values_from = matches("_"), names_vary = "slowest")
tx3

tx3 %>% write_csv(file = file_out$tab3);
