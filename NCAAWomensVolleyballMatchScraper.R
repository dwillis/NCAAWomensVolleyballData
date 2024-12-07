library(tidyverse)
library(lubridate)
library(rvest)
library(janitor)

teams <- read_csv("url_csvs/ncaa_womens_volleyball_teamurls_2024.csv")

root_url <- "https://stats.ncaa.org"
season <- "2024"

matchstatstibble <- tibble()

matchstatsfilename <- paste0("data/ncaa_womens_volleyball_matchstats_", season, ".csv")

for (i in seq_len(nrow(teams))){
  
  schoolfull <- teams$school[i]
  schoolpage <- teams$matchstatsurl[i] %>% read_html()

    # Extract NCAA ID from URL
  ncaa_id <- str_extract(teams$matchstatsurl[i], "(?<=org_id=)\\d+")
  
  matches <- schoolpage %>% html_nodes(xpath = '//*[@id="game_breakdown_div"]/table') %>% html_table(fill=TRUE)
  
  matches <- matches[[1]] %>% slice(3:n()) %>% row_to_names(row_number = 1) %>% clean_names() %>% remove_empty(which = c("cols")) %>% mutate_all(na_if,"") %>% fill(c(date, result)) %>% mutate_at(vars(4:18),  replace_na, '0') %>% mutate(date = mdy(date), home_away = case_when(grepl("@",opponent) ~ "Away", TRUE ~ "Home"), opponent = gsub("@.*, [A-Z]{2}", "", opponent), opponent = gsub("@ ","",opponent), WinLoss = case_when(grepl("L", result) ~ "Loss", grepl("W", result) ~ "Win"), result = gsub("L ", "", result), result = gsub("W ", "", result)) %>% separate(result, into=c("team_score", "opponent_score")) %>% rename(result = WinLoss) %>% mutate(team = schoolfull)  %>% rename(opponent_info = opponent) %>% mutate(opponent = case_when(opponent_info == "Defensive Totals" ~ lag(opponent_info, n=1), TRUE ~ opponent_info)) %>% select(date, team, opponent, home_away, result, team_score, opponent_score, everything()) %>% clean_names() %>% mutate_at(vars(-date, -opponent, -home_away, -result, -team, -opponent_info), ~str_replace(., "/", "")) %>% mutate_at(vars(-date, -team, -opponent, -home_away, -result, -opponent_info), as.numeric)
  
  teamside <- matches %>% filter(opponent_info != "Defensive Totals") %>% select(-opponent_info)
  
  opponentside <- matches %>% filter(opponent_info == "Defensive Totals") %>% select(-opponent_info) %>% select(-home_away) %>% rename_with(.cols = 8:21, function(x){paste0("defensive_", x)})
  
  joinedmatches <- inner_join(teamside, opponentside, by = c("date", "team", "opponent", "result", "team_score", "opponent_score"))
  
  joinedmatches <- joinedmatches %>% mutate(result = case_when(
    team_score > opponent_score ~ 'W',
    team_score < opponent_score ~ 'L',
  ))
  
  # Add ncaa_id column before team column
  joinedmatches <- joinedmatches %>% 
    mutate(ncaa_id = ncaa_id) %>%
    select(ncaa_id, everything())
  
  matchstatstibble <- bind_rows(matchstatstibble, joinedmatches)
  
  message <- paste0("Adding ", schoolfull)
  
  print(message)
  
  Sys.sleep(2)
}

write_csv(matchstatstibble, matchstatsfilename)
