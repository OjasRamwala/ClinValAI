rm(list = ls());
library(magrittr);
library(tidyverse);


file_in = list(
  data = str_glue("Data/nwscore-exam-data.csv")
);

file_out = list(
  tab1 = "Output/Tables/table1.csv"
);



###
# Data
###

if (1) {
  data = file_in$data %>% read_csv();
}


###
# Table 1
###

rx = data %>%
  mutate(
    g = "a"
  ) %>%
  bind_rows(
    .,
    mutate(
      .,
      g = if_else(b_bc_5y == 1, "y", "n")
    )
  ) %>%
  mutate(
    g = g %>%
      factor(
        levels = c("a", "y", "n")
      )
  ) %>%
  select(nwsimagingid, g, age_cat, race_cat2, b_dens) %>%
  mutate(
    age_cat = age_cat %>% factor(),
    race_cat2 = race_cat2 %>%
      factor(levels = c("White", "Black", "Asian", "Other", "Unknown")),
    b_dens = b_dens %>%
      factor(levels = 0:1) %>%
      fct_na_value_to_level("Unknown2")
  ) %>%
  pivot_longer(-c(nwsimagingid, g)) %>% 
  mutate(
    name = name %>% fct_inorder()
  ) %>%
  group_by(g, name, value) %>%
  count() %>%
  group_by(g, name) %>%
  mutate(
    n_tot = n %>% sum(),
    n_nonmissing = if_else(value %in% c("Unknown", "Unknown2"), 0, n) %>% sum(),
    p = n / n_nonmissing,
    s = case_when(
      value %in% c("Unknown", "Unknown2") ~ n %>% formatC(format = "d", big.mark = ","),
      T ~ str_glue("{formatC(n, format = 'd', big.mark = ',')} ({sprintf('%.1f%%', 100*p)})") %>% as.character()
      #T ~ sprintf("%d (%.1f%%)", n, p * 100)
    )
  ) %>%
  ungroup()

tx1 = rx %>%
  select(g:value, s) %>%
  nest(x = c(value, s)) %>%
  mutate(
    x = x %>%
      map(
        ~ .x %>%
          bind_rows(
            tibble(value = "First", s = ""),
            .
          )
      )
  ) %>%
  unnest(x) %>%
  pivot_wider(names_from = c("g"), values_from = "s") %>%
  mutate(
    across(
      matches("^(a|y|n)$"),
      ~ case_when(
        !is.na(.x) ~ .x,
        grepl("Unknown", value) ~ "0",
        T ~ "0 (0.0%)"
      )
    )
  ) %>%
  add_column(sp1 = "", .after = "a")
tx1

tx1 %>% write_csv(file = file_out$tab1);
