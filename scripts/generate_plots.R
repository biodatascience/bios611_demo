library(tidyverse)
library(reshape2)
library(modelr)
library(maps)

args = commandArgs(trailingOnly=TRUE)
DATA_DIR = args[1]
RESULTS_DIR = args[2]
data_path = file.path(DATA_DIR, 'combined_wbdata.csv')

# Read in the combined data set
wb_df = read_delim(data_path, delim = '\t')

# Plot all variables against year
wb_df %>%
  select(-c('Indicator.Name')) %>%
  ggplot(aes(x=Year, y=Value)) +
  geom_line(size=0.7, alpha=0.2, aes(color=Country.Code)) +
  geom_smooth(size=1.2, color='black') +
  facet_grid(rows = vars(Indicator.Code), scales='free') +
  ylab(NULL) +
  theme_minimal() +
  theme(legend.position = "null")

ggsave(file.path(RESULTS_DIR, 'global_trends.png'), height=5, width=6)


# Plot GDP start and end, normalized to start (so that end result is a fold-change)
wb_norm_df = wb_df %>%
  select(-c('Indicator.Name')) %>%
  spread(key=Indicator.Code, value=Value) %>%
  filter(Year == min(Year) | Year == 2017) %>%
  select(c(Country.Name, Year, GDP.Current.US.Dollars)) %>% 
  spread(key=Year, value=GDP.Current.US.Dollars) %>%
  na.omit() %>%
  group_by(Country.Name) %>%
  mutate(Norm.GDP.1960 = `1960` / `1960`, Norm.GDP.2017 = `2017` / `1960`, log.2017=log(Norm.GDP.2017)) %>%
  ungroup()

# Calculate mean, standard deviation, and identify outliers
mean_2017 = mean(wb_norm_df$log.2017)
sd_2017 = sd(wb_norm_df$log.2017)
outlier_thresh_2017a = mean_2017 + 3*sd_2017
outlier_thresh_2017b = mean_2017 - 3*sd_2017
fast_nations = wb_norm_df %>% arrange(log.2017) %>% top_n(5) %>% arrange(-log.2017) %>% mutate(growth='fast')
slower_nations = wb_norm_df %>% arrange(log.2017) %>% top_n(-5) %>% mutate(growth='slow')

# Rename countries to match map designations
fast_nations$Country.Name[fast_nations$Country.Name == 'Korea, Rep.'] = 'South Korea'
slower_nations$Country.Name[slower_nations$Country.Name == 'Congo, Dem. Rep.'] = 'Democratic Republic of the Congo'

outlier_nations = rbind(fast_nations, slower_nations)

p = wb_norm_df %>%
  ggplot(aes(log.2017)) +
  geom_histogram(alpha=0.6) +
  geom_vline(xintercept = mean_2017, color='black', size=0.8) +
  geom_vline(xintercept = outlier_thresh_2017a, color='red', size=0.2, alpha=0.4) +
  geom_vline(xintercept = outlier_thresh_2017b, color='red', size=0.2, alpha=0.4) +
  xlab('Log Fold Change GDP 1960-2017') +
  ylab('Nations Count') +
  theme_minimal() +
  annotate("text", x = mean_2017 + sd_2017*1.5, y = 16, label = "3 Standard Deviations") +
  annotate("text", x = mean_2017 + sd_2017*1.5, y = 16, size=8, label = "<                    >") 
  

for (i in 1:nrow(fast_nations)){
  p = p + annotate("text", 
                   x = fast_nations$log.2017[i], 
                   y = 3 + i*0.6, 
                   label = fast_nations$Country.Name[i],
                   color='red')
}

for (i in 1:nrow(slower_nations)){
  p = p + annotate("text", 
                   x = slower_nations$log.2017[i], 
                   y = 3 + i*0.6, 
                   label = slower_nations$Country.Name[i],
                   color='red')
}

ggsave(file.path(RESULTS_DIR, 'fold_changes_gdp.png'), plot=p, height=5, width=7)


# How GDP relates to percent population over 65 in the year 2016   
gdp_by_p65 = wb_df %>% 
  select(-c(Indicator.Name)) %>%
  filter(Year==2016) %>%
  spread(key=Indicator.Code, value=Value) %>%
  mutate(l.gdp=log2(GDP.Current.US.Dollars), l.p65=log2(Percent.Pop.Over.65)) 

mod_gdp_p65 = lm(Percent.Pop.Over.65~l.gdp, data=gdp_by_p65)

grid = gdp_by_p65 %>% 
  data_grid(GDP.Current.US.Dollars = seq_range(GDP.Current.US.Dollars, 80)) %>% 
  mutate(l.gdp = log2(GDP.Current.US.Dollars)) %>% 
  add_predictions(mod_gdp_p65, "Percent.Pop.Over.65") 

ggplot(gdp_by_p65, aes(x=GDP.Current.US.Dollars, y=Percent.Pop.Over.65)) + 
  geom_point() + 
  geom_line(data = grid, colour = "red", size = 1) +
  scale_x_log10() +
  theme_minimal()

gdp_by_p65 = gdp_by_p65 %>% 
  add_residuals(mod_gdp_p65, "lresid")

ggsave(file.path(RESULTS_DIR, 'p65_by_gdp.png'), height=5, width=5)


# How birth rate relates to percent population over 65 in the year 2016   
br_by_p65 = wb_df %>% 
  select(-c(Indicator.Name)) %>%
  filter(Year==2016) %>%
  spread(key=Indicator.Code, value=Value) %>%
  mutate(l.br=log2(Births.Per.1000), l.p65=log2(Percent.Pop.Over.65)) 

mod_br_p65 = lm(l.p65~l.br, data=br_by_p65)

grid = br_by_p65 %>% 
  data_grid(Births.Per.1000 = seq_range(Births.Per.1000, 40)) %>% 
  mutate(l.br = log2(Births.Per.1000)) %>% 
  add_predictions(mod_br_p65, "l.p65") %>% 
  mutate(Percent.Pop.Over.65 = 2 ^ l.p65)

ggplot(br_by_p65, aes(x=Births.Per.1000, y=Percent.Pop.Over.65)) + 
  geom_point() + 
  geom_line(data = grid, colour = "red", size = 1) +
  theme_minimal()

br_by_p65 = br_by_p65 %>% 
  add_residuals(mod_br_p65, "lresid") %>%
  mutate(resid = 2^lresid)

ggsave(file.path(RESULTS_DIR, 'p65_by_br.png'), height=5, width=5)


# Which countries have far more or far fewer seniors than expected based on birth rate?
mean_resid_br = mean(br_by_p65$resid, na.rm=T)
sd_resid_br = sd(br_by_p65$resid, na.rm=T)
outlier_thresh_br = mean_resid_br - 3*sd_resid_br
fewer_seniors_br = br_by_p65 %>% filter(resid < outlier_thresh_br) %>% mutate(sen='few')
more_seniors_br = br_by_p65 %>% arrange(resid) %>% top_n(5) %>% mutate(sen='more')

# Fix names to match map
more_seniors_br$Country.Name[more_seniors_br$Country.Name == 'United Kingdom'] = 'UK'
more_seniors_br$Country.Name[more_seniors_br$Country.Name == 'Virgin Islands (U.S.)'] = 'Virgin Islands'

unusual_num_seniors_br = rbind(fewer_seniors_br, more_seniors_br)

set.seed(2019)

p2 = ggplot(br_by_p65, aes(x=resid)) +
  geom_histogram(alpha=0.6, fill='#99badd') +
  geom_vline(xintercept = mean_resid_br) +
  geom_vline(xintercept = outlier_thresh_br, color='red', alpha=0.4) +
  ylab('Nations Count') +
  xlab('Deviation from Expected % Over 65') +
  theme_minimal() +
  coord_flip()

for (i in 1:nrow(fewer_seniors_br)){
  p2 = p2 + annotate("text", 
                   x = fewer_seniors_br$resid[i] + 0.06*rnorm(n=1), 
                   y = 4, 
                   label = fewer_seniors_br$Country.Name[i],
                   color='red')
}

for (i in 1:nrow(more_seniors_br)){
  p2 = p2 + annotate("text", 
                     x = more_seniors_br$resid[i], 
                     y = 4, 
                     label = more_seniors_br$Country.Name[i],
                     color='red')
}
print(p2)
ggsave(file.path(RESULTS_DIR, 'p65_residuals_by_br.png'), plot=p2, height = 6, width = 5)


# Plot birth rates over time in nations with unusual percentages over 65
p4 = wb_df %>% filter(Country.Name %in% unusual_num_seniors_br$Country.Name) %>%
  left_join(unusual_num_seniors_br %>% select(Country.Name, sen), by='Country.Name') %>%
  spread(key=Indicator.Code, value=Value) %>%
  ggplot(aes(x=Year, y=Births.Per.1000)) +
  geom_point(alpha=0.3, aes(color=sen)) +
  geom_smooth(se=FALSE, size=2, aes(group=sen, color=sen)) +
  scale_color_brewer(palette="Dark2") +
  theme_minimal() +
  theme(legend.position = 'null') +
  annotate('text', x=2006, y=30, label='Fewer Seniors than Expected', color='DarkGreen', size=5) +
  annotate('text', x=1982, y=10, label='More Seniors than Expected', color='DarkRed', size=5) 
  #ggtitle('Fewer seniors than expected means recent birth rate decrease')

ggsave(file.path(RESULTS_DIR, 'br_over_time.png'), plot=p4, height=5, width=7)


# Map of countries
countries_of_note = tibble(region = c(fast_nations$Country.Name, 
                                      slower_nations$Country.Name,
                                      fewer_seniors_br$Country.Name,
                                      more_seniors_br$Country.Name),
                           type = c(rep('Fast Growth', nrow(fast_nations)),
                                    rep('Slow Growth', nrow(slower_nations)),
                                    rep('Few Seniors', nrow(fewer_seniors_br)),
                                    rep('More Seniors', nrow(more_seniors_br)))
                           )

world_map = map_data("world")
countries_of_note_map = world_map %>%
  right_join(countries_of_note, by='region')
  
ggplot(world_map, aes(long, lat, group=group)) +
  geom_polygon(fill="lightgray", colour="darkgray", size=1) +
  geom_polygon(data=countries_of_note_map, aes(fill=type)) +
  ggtitle("Map of World") +
  xlim(-20, 165) +
  ylim(-50, 80) +
  theme_minimal() +
  ggtitle('Notable Nations')

ggsave(file.path(RESULTS_DIR, 'world_map.png'), height=7, width=10)
