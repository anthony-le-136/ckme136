---
title: "Google Play Store Data Analysis"
author: "Anthony Le"
output: github_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

```{r,echo=FALSE}
#install.packages("tidyverse")
#install.packages('caret', dependencies = TRUE)
#install.packages('e1071')
#install.packages('DMwR')
#install.packages('pROC')
library(DMwR)
library(e1071)
library(caret)
library(tidyverse)
library(lubridate)
library(pROC)
set.seed(1994)
```

## Data Import

Import Data 
```{r}
playstore <- read.csv('googleplaystore.csv', header = TRUE)
```


Initial Data
```{r,echo=FALSE}
str(playstore)
summary(playstore)

```

## Transform Data

1. Remove columns and duplicated rows

```{r, echo=FALSE}
playstore$App <- NULL
playstore$Current.Ver <- NULL
playstore$Genres <- NULL
playstore$Last.Updated <- NULL
playstore <- na.omit(playstore)
playstore <- subset(unique(playstore))

```
2. App ratings should have a maximum value of 5

```{r, echo=FALSE}
playstore <- subset(playstore[playstore$Rating <= 5,])

```


3. Remove extra characters, convert Size to consistent format, remove apps under 1MB, and remove apps with 0 installs

```{r,echo=FALSE}
playstore$Installs <- gsub("+", "", playstore$Installs, fixed = TRUE)
playstore$Installs <- gsub(",", "", playstore$Installs, fixed = TRUE)
playstore$Price <- gsub("$", "", playstore$Price, fixed = TRUE)
playstore$Price <- gsub("0", "0.00", playstore$Price, fixed = TRUE)
playstore <- subset(playstore[playstore$Size != "Varies with device",])

playstore <- playstore[!grepl("k",playstore$Size),]
playstore$Size <- gsub("M", "", playstore$Size)
playstore$Size <- gsub(",", "", playstore$Size, fixed = TRUE)
playstore$Size <- as.numeric(playstore$Size)
playstore <- as.vector(na.omit(playstore))


```


4. Convert columns to appropriate variable types

```{r, echo=FALSE}

# Android.Ver should have numeric values only
playstore$Android.Ver <- gsub("and up","",playstore$Android.Ver,fixed=TRUE)
playstore$Android.Ver <- gsub("Varies with device",NA,playstore$Android.Ver)
playstore <- as.vector(na.omit(playstore))
playstore$Android.Ver <- substr(playstore$Android.Ver,start=1,stop=3)

# Change data type of  Reviews, Rating, Price, Installs
playstore$Reviews <- as.numeric(playstore$Reviews)
playstore$Rating <- as.numeric(playstore$Rating)
playstore$Price <- as.numeric(playstore$Price)
playstore$Installs <- as.numeric(playstore$Installs)
playstore$Category <- factor(playstore$Category)

# Remove NaN values in Type
playstore$Type <- gsub(NaN,NA,playstore$Type,fixed=TRUE)
playstore$Type <- factor(playstore$Type)
playstore$Android.Ver <- gsub(NaN,NA,playstore$Android.Ver,fixed=TRUE)
playstore$Android.Ver <- factor(playstore$Android.Ver)


playstore <- na.omit(playstore)
str(playstore)
```


```{r, echo=FALSE}
hist(playstore$Rating, main = "Distribution of App Rating, Continuous", breaks = 100, xlim = c(0,5), xlab = "Rating", ylab = "Count", col="gold")

```

There is a clear class imbalance, as there are far more apps rated 4.0 and above

## Create Ratings Intervals

Split continuous rating (1.0-5.0) into 2 intervals and convert to factor
```{r}
playstore$Rating <- cut(as.numeric(playstore$Rating), breaks = c(1,4,5), labels = c('0','1'))
plot(playstore$Rating, main = "Distribution of App Rating, Categorical", xlab = "Rating", ylab = "Count", col="red")

playstore$Rating = factor(playstore$Rating)
playstore <- na.omit(playstore)

```


## Upsampling


```{r,echo=FALSE}
#Remove levels with single data points
playstore <- subset(playstore[-which(playstore$Android.Ver == "1.0"),])
playstore <- subset(playstore[-which(playstore$Android.Ver == "7.1"),])
playstore <- subset(playstore[!playstore$Content.Rating == "Adults only 18+",])
playstore <- subset(playstore[!playstore$Content.Rating == "Unrated",])

playstore$Android.Ver <- factor(playstore$Android.Ver)
playstore$Content.Rating <- factor(playstore$Content.Rating)

# Training and test split
split <- createDataPartition(playstore$Rating, times = 1,p = 0.7,list = FALSE)
ps_training <- playstore[split,]
ps_test <- playstore[-split,]

#Upsample minority class
ps_training <- SMOTE(Rating ~ ., ps_training, perc.over = 200,perc.under = 150)
upsample_plot <- plot(ps_training$Rating, main = 'SMOTE Oversampling', xlab = 'Rating', ylab = 'Count')
print(upsample_plot)
```


## Random Forest

```{r}

model_rf <- train(ps_training[,-2],ps_training$Rating,method = "rf", trControl = trainControl(method="cv",number = 3,savePredictions = TRUE))


```
## Naive Bayes 
```{r}

model_nb <- train(ps_training[,-2], ps_training$Rating,method = "naive_bayes", trControl = trainControl(method="cv",number = 3,savePredictions = TRUE))


```

## Logistic Regression
```{r}
#ps_training_lr <- ps_training
#ps_training_lr$Rating <- as.character(ps_training_lr$Rating)
#ps_training_lr[ps_training_lr$Rating == 'Mediocre'] <- '0'
#ps_training_lr[ps_training_lr$Rating == 'High'] <- '1'
#ps_training_lr$Rating <- as.factor(ps_training_lr$Rating)

model_lr <- train(ps_training[,-2], ps_training$Rating, method = "glm", trControl = trainControl(method = "cv",number = 3,savePredictions = TRUE))

```

## Performance Measuring

```{r}
rf_predict <- predict(model_rf, ps_test, type = "prob")
rf_roc <- roc(ps_test$Rating, rf_predicted$`1`)
plot.roc(rf_roc)

auc(rf_roc)
```

```{r}
nb_predict <- predict(model_nb, ps_test, type = "prob")
nb_roc <- roc(ps_test$Rating, nb_predicted$`1`)
plot.roc(nb_roc)

auc(nb_roc)
```

```{r}
lr_predict <- predict(model_lr, ps_test, type = "prob")
lr_roc <- roc(ps_test$Rating, lr_predicted$`1`)
plot.roc(lr_roc)

auc(lr_roc)
```
