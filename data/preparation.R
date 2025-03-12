library(tidyverse)

# Read in data
child <- read_csv("data/child.csv", col_names = TRUE)
parent <- read_csv("data/parent.csv", col_names = TRUE)

########### Data Cleaning ###########

# Remove rows that do not contain survey data
parent <- parent[-c(1, 2),]
child <- child[-c(1, 2),]

# Parent cleaning
parent <- parent %>% 
  # remove survey testing responses 
  filter(Q_CHL != "preview") %>% 
  # self consent = agree
  filter(Pconsent_self == "Agree") %>% 
  # child consent = agree
  filter(`Pconsent-child` == "Agree") %>% 
  # remove duplicates
  mutate(Q_RelevantIDDuplicate = 
           # Logical operators
           ifelse(is.na(Q_RelevantIDDuplicate), FALSE, TRUE)) %>% 
  filter(Q_RelevantIDDuplicate != TRUE) %>% 
  # filter attn checks
  filter(yt_opinions_4 == "A lot") %>% 
  # Ensure that time is numeric
  mutate(Ptime = as.numeric(Ptime))

# Child cleaning
child <- child %>% 
  # remove survey testing responses
  filter(Q_CHL != "preview") %>% 
  # consent = yes
  filter(Cconsent == "YES") %>% 
  # filter attn checks 
  filter(homophily_behave_5 == "Agree")

# Remove unnecessary columns
parent <- parent %>% 
  select(-c(StartDate:Q_RelevantIDLastStartDate, gc:tg))
child <- child %>% 
  select(-c(StartDate:UserLanguage, opp, Q_BallotBoxStuffing:tg))

# Merge data frames
youtube <- inner_join(parent, child, by = join_by(transaction_id))

# Additional cleaning - favorite YouTuber
youtube <- youtube %>% 
  mutate(favorite = case_when(
    favorite == "Mr beast" ~ "MrBeast",
    favorite == "mr best" ~ "MrBeast",
    favorite == "mr beast" ~ "MrBeast",
    favorite == "Me beast" ~ "MrBeast",
    is.na(favorite) ~ "None",
    TRUE ~ favorite
  )) %>% 
  mutate(youtuber = ifelse(
    favorite == "MrBeast",
    "MrBeast",
    "Not MrBeast"
  ))

# Additional cleaning using stringr
youtube <- youtube %>% 
  # only keep last character in friend choice task
  mutate(friend = str_sub(friend, start = -1, end = -1)) %>% 
  # trim whitespace from free response
  mutate(favorite = str_squish(favorite))

########### Data Wrangling ###########

# Making relevant items into factors and creating levels 
youtube <- youtube %>% 
  # days
  mutate(days = as_factor(days)) %>% 
  mutate(days = fct_relevel(days, c("Never", 
                                    "1 to 2 days a week",
                                    "3 to 4 days a week",
                                    "5 to 6 days a week",
                                    "Every day"))) %>% 
  # Ctime
  mutate(Ctime = as_factor(Ctime)) %>% 
  mutate(Ctime = fct_relevel(Ctime, c("About 15 minutes a day", 
                                      "About 30 minutes a day",
                                      "About 45 minutes a day",
                                      "About 1 hour a day",
                                      "About 1 and 1/2 hours a day",
                                      "More than 2 hours"))) %>% 
  # malleable, regularities, homophily, parasocial
  mutate(
    across(c(malleable_1, malleable_2, malleable_3, malleable_4, regularities_1, regularities_2, regularities_3, regularities_4, regularities_5, regularities_6, regularities_7, `homophily_appear_1`, `homophily_appear_2`, `homophily_appear_3`, `homophily_appear_4`, `homophily_appear_5`, `homophily_behave_1`, `homophily_behave_2`, `homophily_behave_3`, `homophily_behave_4`, `homophily_behave_6`, parasocial_1, parasocial_2, parasocial_3, parasocial_4, parasocial_5),
           ~ fct_relevel(as_factor(.),
                         "Really disagree",
                         "Disagree",
                         "I don't know",
                         "Agree",
                         "Really  agree"
           )))  %>% 
  # outgroup-freq
  mutate(`outgroup_freq` = as_factor(`outgroup_freq`)) %>% 
  mutate(`outgroup_freq` = str_trim(`outgroup_freq`)) %>% 
  mutate(`outgroup_freq` = fct_relevel(`outgroup_freq`, c("Never",
                                                          "Rarely",
                                                          "Sometimes",
                                                          "Often",
                                                          "Very often")))

# Adding additional variables
youtube <- youtube %>% 
  # Making a binary 'daily' variable
  mutate(
    daily = ifelse(
      days == "Every day",
      "Every Day",
      "Not Every Day"
    )) %>% 
  # Making a binary 'race' variable
  mutate(
    race = ifelse(
      race_ethnicity == "White",
      "White",
      "Non-White"
    ))

# Recoding factor variables as numeric variables to create aggregate scores
youtube <- youtube %>% 
  mutate(
    across(c(`homophily_appear_1`, `homophily_appear_2`, `homophily_appear_3`, `homophily_appear_4`, `homophily_appear_5`, `homophily_behave_1`, `homophily_behave_2`, `homophily_behave_3`, `homophily_behave_4`, `homophily_behave_6`, parasocial_1, parasocial_2, parasocial_3, parasocial_4, parasocial_5),
           ~ recode (.,
                     "Really disagree" = 1,
                     "Disagree" = 2,
                     "I don't know" = 3,
                     "Agree" = 4,
                     "Really agree" = 5
           ))) %>% 
  mutate(
    across(c(malleable_1, malleable_2, malleable_3, malleable_4),
           ~ recode(.,
                    "Really disagree" = 1,
                    "Disagree" = 2,
                    "Neither agree nor disagree" = 3,
                    "Agree" = 4,
                    "Really agree" = 5
           ))) %>%  
  mutate(
    across(c(regularities_1, regularities_2, regularities_3, regularities_4, regularities_5, regularities_6, regularities_7),
           ~ recode(.,
                    "Really disagree" = 1,
                    "Disagree" = 2,
                    "Neither agree nor disagree" = 3,
                    "Agree" = 4,
                    "Really  agree" = 5
           ))) %>%  
  select(-c(homophily_behave_5))

### Dealing with birthdays - obtaining child age
# Today's date
date_today <- Sys.Date() 

# Birthday function (obtained with help from chatGPT)
# function takes arguments: data frame, column, and object (date today)
birthday <- function(df, column_name, date_today) {
  df <- df %>%
    mutate(
      # Convert valid date strings to Date format in new column
      bday_date = if_else(
        # Search for RegEx of "xx/xx/xxxx" form in the indicated column
        grepl("^\\d{2}/\\d{2}/\\d{4}$", .[[column_name]]), 
        # If there is a string in such a form, return a date in the form of mm/dd/yyyy
        as.Date(.[[column_name]], format = "%m/%d/%Y"), 
        # Otherwise, keep objects as NA of form 'date'
        NA_Date_
      ),
      
      # Extract last 4 characters for non-date values in new column
      bday_year = if_else(
        # If NA in bday_date,
        is.na(bday_date), 
        # Take the only the last 4 characters (year)
        as.numeric(substr(.[[column_name]], nchar(.[[column_name]]) - 3, nchar(.[[column_name]]))), 
        # Otherwise, keep NA as numeric objects
        NA_real_
      ),
      
      # Calculate age based on actual date or extracted year in new column
      age = if_else(
        # If not an NA value in bday_date
        !is.na(bday_date), 
        # If in date form, take difference between today's date and bday_date, and convert to years
        as.numeric(difftime(date_today, bday_date, units = "days")) / 365.25, 
        # If otherwise, subtract the year obtained in bday_year from this year 
        2025 - bday_year
      )
    ) %>%
    
    # Remove intermediate columns
    select(-bday_date, -bday_year)  
  
  return(df)
}

# Apply birthday function to YouTube data frame
youtube <- birthday(youtube, "bday", date_today)

# Determine whether or not an age is within age range
youtube <- youtube %>% 
  mutate(
    in_range = case_when(
      age < 14 ~ TRUE,
      age >= 14 ~ FALSE
    )
  )

### Composite scores
# Racial attitudes score -- total possible score = 20
youtube <- youtube %>% 
  mutate(malleable_score = rowSums(across(malleable_1:malleable_4))) %>% 
  mutate(malleable_score = malleable_score/20)

# Parasocial relationship scores (each block separately, then aggregate)
youtube <- youtube %>% 
  # homophily-appear -- total possible score = 20
  mutate(h_appear_score = rowSums(across(homophily_appear_1:homophily_appear_5))) %>% 
  # homophily-behave -- total possible score = 20
  mutate(h_behave_score = rowSums(across(homophily_behave_1:homophily_behave_6))) %>% 
  # parasocial -- total possible score = 20
  mutate(parasocial_score = rowSums(across(parasocial_1:parasocial_5))) %>% 
  #Composite scores
  mutate(composite = rowSums(across(h_appear_score:parasocial_score))) %>% 
  # Proportion scores
  mutate(h_appear_score = h_appear_score/20) %>%
  mutate(h_behave_score = h_behave_score/20) %>%
  mutate(parasocial_score = parasocial_score/20) %>%
  mutate(composite = composite/60)

# Racial regularities score (behavior) -- total possible score = 35
youtube <- youtube %>% 
  # Reverse coded items
  mutate(across(c(regularities_3, regularities_5, regularities_7), ~ 6 - .)) %>% 
  # Score
  mutate(regularity_score = rowSums(across(regularities_1:regularities_7))) %>% 
  mutate(regularity_score = regularity_score/35)

### Write out data set
write_csv(youtube, "data/youtube.csv")
